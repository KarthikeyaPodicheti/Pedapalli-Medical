#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
container_name="pm-b2b-db-test-${GITHUB_RUN_ID:-local}-$$"

cleanup() {
  docker stop "$container_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --rm --name "$container_name" -e POSTGRES_PASSWORD=localcheck -d postgres:17-alpine >/dev/null
database_ready=false
for _ in {1..60}; do
  # TCP becomes ready only for the final server, not the temporary init server.
  if docker exec "$container_name" pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1; then
    database_ready=true
    break
  fi
  sleep 1
done
if [[ "$database_ready" != true ]]; then
  docker logs "$container_name" >&2 || true
  echo "PostgreSQL test container did not become ready." >&2
  exit 1
fi

docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/tests/bootstrap.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/migrations/202610070001_store.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/migrations/202610090001_b2b_foundation.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/tests/b2b_integration.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/migrations/202610100001_free_tier_security.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/migrations/202610100002_catalog_price_guard.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/migrations/202610100003_optional_gstin.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/tests/free_tier_security.sql"
# PRD batch inventory migration smoke test
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/migrations/202610110001_batch_inventory_foundation.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/tests/batch_inventory_foundation.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/migrations/202610110002_shadow_batch_allocations.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/tests/shadow_batch_allocations.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/migrations/202610110003_receipt_idempotency.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/tests/receipt_idempotency.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/migrations/202610110004_buyer_pending_cancellation.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/tests/buyer_pending_cancellation.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/migrations/202610110005_batch_safety_operations.sql"
docker exec -i "$container_name" psql -U postgres -v ON_ERROR_STOP=1 < "$repo_root/supabase/tests/batch_safety_operations.sql"

race_order() {
  local buyer_id="$1" request_id="$2"
  docker exec "$container_name" psql -U postgres -v ON_ERROR_STOP=1 -q -c "set role authenticated; select set_config('request.jwt.claim.sub','$buyer_id',false); select public.create_b2b_order(jsonb_build_array(jsonb_build_object('product_id',(select id from public.get_b2b_catalog() where sku='RACE-1'),'quantity',5)),'cod','pickup','$request_id');" >/dev/null 2>&1
}

set +e
race_order '11111111-1111-4111-8111-111111111111' '88888888-8888-4888-8888-888888888888' & first_pid=$!
race_order '22222222-2222-4222-8222-222222222222' '99999999-9999-4999-8999-999999999999' & second_pid=$!
wait "$first_pid"; first_status=$?
wait "$second_pid"; second_status=$?
set -e

successes=0
if [[ "$first_status" -eq 0 ]]; then successes=$((successes+1)); fi
if [[ "$second_status" -eq 0 ]]; then successes=$((successes+1)); fi
if [[ "$successes" -ne 1 ]]; then
  echo "Expected exactly one concurrent last-stock order to succeed; got $successes." >&2
  exit 1
fi
race_state="$(docker exec "$container_name" psql -U postgres -Atc "select stock||':'||(select count(*) from public.orders o join public.order_items i on i.order_id=o.id join public.products p on p.id=i.product_id where p.sku='RACE-1') from public.products where sku='RACE-1';")"
if [[ "$race_state" != '0:1' ]]; then
  echo "Concurrent stock protection failed: $race_state" >&2
  exit 1
fi
echo "Concurrent last-stock test passed"

