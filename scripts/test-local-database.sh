#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
container_name="pm-local-db-test-${GITHUB_RUN_ID:-local}-$$"
cleanup(){ docker stop "$container_name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run --rm --name "$container_name" -e POSTGRES_PASSWORD=localcheck -d postgres:17-alpine >/dev/null
ready=false
for _ in {1..60}; do
  if docker exec "$container_name" pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1; then ready=true;break;fi
  sleep 1
done
if [[ "$ready" != true ]];then docker logs "$container_name" >&2;exit 1;fi

for migration in "$repo_root"/server/sql/*.sql;do
  docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$migration"
done
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/server/tests/batch_core.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/server/tests/imports.sql"

race_order(){
  local buyer="$1" key="$2"
  docker exec "$container_name" psql -U postgres -v ON_ERROR_STOP=1 -q -c "select * from public.create_batch_order('$buyer',jsonb_build_array(jsonb_build_object('product_id','40000000-0000-4000-8000-000000000003','quantity',5)),'cod','pickup','$key','buyer_portal');" >/dev/null 2>&1
}
set +e
race_order '20000000-0000-4000-8000-000000000001' '60000000-0000-4000-8000-000000000001' & first=$!
race_order '20000000-0000-4000-8000-000000000002' '60000000-0000-4000-8000-000000000002' & second=$!
wait "$first";first_status=$?
wait "$second";second_status=$?
set -e
successes=0
if [[ "$first_status" -eq 0 ]];then successes=$((successes+1));fi
if [[ "$second_status" -eq 0 ]];then successes=$((successes+1));fi
if [[ "$successes" -ne 1 ]];then echo "Expected one last-stock order; got $successes" >&2;exit 1;fi
race_state="$(docker exec "$container_name" psql -U postgres -Atc "select reserved||':'||(select count(*) from public.orders o join public.order_items i on i.order_id=o.id where i.product_id='40000000-0000-4000-8000-000000000003') from public.inventory_batches where batch_number='RACE';")"
if [[ "$race_state" != '5:1' ]];then echo "Concurrent reservation failed: $race_state" >&2;exit 1;fi
echo "Local concurrent last-stock test passed"
