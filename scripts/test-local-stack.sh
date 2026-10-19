#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_name="pm-local-integration-${GITHUB_RUN_ID:-local}-$$"
results_dir="$(mktemp -d)"
export LOCAL_DB_PASSWORD="$(openssl rand -hex 24)"
export LOCAL_API_PASSWORD="$(openssl rand -hex 24)"

cleanup(){
  docker compose -p "$project_name" down -v >/dev/null 2>&1 || true
  rm -rf "$results_dir"
}
trap cleanup EXIT

cd "$repo_root"
docker compose -p "$project_name" up --build -d

ready=false
for _ in {1..60}; do
  if curl --fail --silent http://127.0.0.1:8080/api/health > "$results_dir/health.json"; then ready=true;break;fi
  sleep 1
done
if [[ "$ready" != true ]];then
  docker compose -p "$project_name" logs >&2
  exit 1
fi

request(){
  local expected="$1" output="$2";shift 2
  local status
  status="$(curl --silent --show-error --output "$output" --write-out '%{http_code}' "$@")"
  if [[ "$status" != "$expected" ]];then
    echo "Expected HTTP $expected, received $status: $(<"$output")" >&2
    exit 1
  fi
}

request 202 "$results_dir/register.json" -X POST http://127.0.0.1:8080/api/auth/register \
  -H 'Origin: http://localhost:8080' -H 'Content-Type: application/json' \
  --data '{"email":"buyer@example.in","password":"Synthetic buyer password 2026!"}'
request 200 "$results_dir/login.json" -c "$results_dir/cookies.txt" -X POST http://127.0.0.1:8080/api/auth/login \
  -H 'Origin: http://localhost:8080' -H 'Content-Type: application/json' \
  --data '{"email":"buyer@example.in","password":"Synthetic buyer password 2026!"}'
request 201 "$results_dir/buyer.json" -b "$results_dir/cookies.txt" -X POST http://127.0.0.1:8080/api/buyer \
  -H 'Origin: http://localhost:8080' -H 'Content-Type: application/json' \
  --data '{"legalName":"Synthetic Buyer Medical","contactName":"Test Buyer","phone":"9876543210","drugLicence":"DL-SYNTHETIC-001","address":"Market Road, Peddapalli","pincode":"505172"}'
request 200 "$results_dir/catalog.json" -b "$results_dir/cookies.txt" http://127.0.0.1:8080/api/catalog
if ! grep -q '"canTrade":false' "$results_dir/catalog.json";then echo 'Pending buyer unexpectedly gained catalog access' >&2;exit 1;fi
request 503 "$results_dir/order.json" -b "$results_dir/cookies.txt" -X POST http://127.0.0.1:8080/api/orders \
  -H 'Origin: http://localhost:8080' -H 'Content-Type: application/json' \
  --data '{"items":[{"product_id":"40000000-0000-4000-8000-000000000001","quantity":1}],"payment":"cod","fulfilment":"pickup","idempotencyKey":"11111111-1111-4111-8111-111111111111"}'
if ! grep -q 'Ordering remains disabled' "$results_dir/order.json";then echo 'Checkout safety response was not returned' >&2;exit 1;fi

echo 'Local container-stack integration checks passed'
