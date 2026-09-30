#!/bin/sh
#
# Bootstrap Capgo on the self-hosted Supabase stack. Idempotent.
# Run after `supabase db push` of capgo migrations.
#
# Usage:
#   ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=secret sh scripts/init-capgo.sh
#
# ADMIN_PASSWORD is optional: a random one is generated (and printed) when the
# admin user does not exist yet. An existing admin keeps its password.
#
set -e

cd "$(dirname "$0")/.."

SEED="capgo/supabase/seed.sql"
INIT_SQL="capgo-docker/init.sql"
FUNCTIONS_ENV="supabase/volumes/functions/.env"
SUPABASE_ENV="supabase/.env"
DB_CONTAINER="supabase-db"
# URL the database (pg_net) uses to reach edge functions inside the compose network
DB_URL="http://api-gw:8000"

env_get() { grep "^$2=" "$1" 2>/dev/null | head -n1 | cut -d= -f2-; }
psql_db() { docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q "$@"; }

[ -n "$ADMIN_EMAIL" ] || { echo "ERROR: set ADMIN_EMAIL" >&2; exit 1; }
[ -f "$SEED" ] || { echo "ERROR: $SEED not found (git submodule update --init?)" >&2; exit 1; }

SERVICE_ROLE_KEY=$(env_get "$SUPABASE_ENV" SERVICE_ROLE_KEY)
API_URL="http://localhost:$(env_get "$SUPABASE_ENV" API_GW_HTTP_PORT)"

# 1. API_SECRET shared by the database (vault 'apikey') and edge functions
API_SECRET=$(env_get "$FUNCTIONS_ENV" API_SECRET)
if [ -z "$API_SECRET" ] || [ "$API_SECRET" = "testsecret" ]; then
  API_SECRET=$(openssl rand -hex 32)
  if grep -q '^API_SECRET=' "$FUNCTIONS_ENV"; then
    sed -i.bak "s|^API_SECRET=.*|API_SECRET=$API_SECRET|" "$FUNCTIONS_ENV" && rm -f "$FUNCTIONS_ENV.bak"
  else
    echo "API_SECRET=$API_SECRET" >> "$FUNCTIONS_ENV"
  fi
  echo "===> Generated new API_SECRET in $FUNCTIONS_ENV, recreating functions"
  docker compose up -d --force-recreate functions >/dev/null
fi

# 2. Admin user via the Auth admin API (creates auth.identities too)
ADMIN_ID=$(psql_db -tA -c "select id from auth.users where email = lower('$ADMIN_EMAIL')")
if [ -z "$ADMIN_ID" ]; then
  if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=$(openssl rand -base64 18)
    GENERATED_PASSWORD=1
  fi
  RESPONSE=$(curl -sS -X POST "$API_URL/auth/v1/admin/users" \
    -H "apikey: $SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"email_confirm\":true}")
  ADMIN_ID=$(printf '%s' "$RESPONSE" | sed -n 's/^{"id":"\([^"]*\)".*/\1/p')
  [ -n "$ADMIN_ID" ] || { echo "ERROR: cannot create admin: $RESPONSE" >&2; exit 1; }
  echo "===> Created admin $ADMIN_EMAIL ($ADMIN_ID)"
  [ -n "$GENERATED_PASSWORD" ] && echo "     password: $ADMIN_PASSWORD"
else
  echo "===> Admin $ADMIN_EMAIL already exists ($ADMIN_ID)"
fi

# 3. SQL bootstrap, with the RBAC catalog taken from capgo's seed.sql
RBAC_TMP=$(mktemp)
trap 'rm -f "$RBAC_TMP"' EXIT
sed -n '/Repopulating RBAC permissions/,/Ensure dedicated apikey management/p' "$SEED" | sed '1d;$d' > "$RBAC_TMP"
[ -s "$RBAC_TMP" ] || { echo "ERROR: RBAC catalog markers not found in $SEED" >&2; exit 1; }

awk -v rbac="$RBAC_TMP" '
  /^-- @RBAC_CATALOG@$/ { while ((getline line < rbac) > 0) print line; next }
  { print }
' "$INIT_SQL" | psql_db --single-transaction \
  -v admin_id="$ADMIN_ID" -v api_secret="$API_SECRET" -v db_url="$DB_URL"

psql_db -tA -c "select 'permissions: ' || count(*) from public.permissions" \
             -c "select 'role_permissions: ' || count(*) from public.role_permissions"
echo "===> Capgo bootstrap done"
