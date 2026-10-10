#!/usr/bin/env bash
set -euo pipefail

required=(SUPABASE_DB_URL BACKUP_ENCRYPTION_PASSPHRASE CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID R2_BACKUP_BUCKET)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "Required backup setting is missing: $name" >&2
    exit 1
  fi
done

backup_dir="$(mktemp -d)"
if [[ -z "$backup_dir" || ! -d "$backup_dir" ]]; then
  echo "Could not create a temporary backup directory." >&2
  exit 1
fi
trap 'rm -rf -- "$backup_dir"' EXIT

stamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
archive="$backup_dir/pedapalli-medical-$stamp.tar.gz"
encrypted="$archive.gpg"
object="database/pedapalli-medical-$stamp.tar.gz.gpg"

npx --yes supabase@2.120.0 db dump --db-url "$SUPABASE_DB_URL" --schema public --file "$backup_dir/public-schema.sql"
npx --yes supabase@2.120.0 db dump --db-url "$SUPABASE_DB_URL" --schema public --data-only --use-copy --file "$backup_dir/public-data.sql"
npx --yes supabase@2.120.0 db dump --db-url "$SUPABASE_DB_URL" --schema auth --data-only --use-copy --file "$backup_dir/auth-data.sql"

tar -C "$backup_dir" -czf "$archive" public-schema.sql public-data.sql auth-data.sql
printf '%s' "$BACKUP_ENCRYPTION_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 \
  --symmetric --cipher-algo AES256 --output "$encrypted" "$archive"

printf '%s' "$BACKUP_ENCRYPTION_PASSPHRASE" | gpg --batch --quiet --pinentry-mode loopback --passphrase-fd 0 \
  --decrypt "$encrypted" | tar -tzf - >/dev/null
(cd "$backup_dir" && sha256sum "$(basename "$encrypted")" > "$(basename "$encrypted").sha256")

npx --yes wrangler@4.45.0 r2 object put "$R2_BACKUP_BUCKET/$object" --file "$encrypted" --remote
npx --yes wrangler@4.45.0 r2 object put "$R2_BACKUP_BUCKET/$object.sha256" --file "$encrypted.sha256" --remote

echo "Encrypted backup uploaded to R2 as $object"
