# Capgo on self-hosted Supabase

Local/self-hosted [Capgo](https://github.com/Cap-go/capgo) running on the official
Supabase Docker stack.

```
capgo/                        Capgo (git submodule)
capgo-docker/                 Capgo console image: Dockerfile, nginx, .env, init.sql
scripts/                      sync-capgo-functions.sh, init-capgo.sh
docker-compose.yml            includes supabase/ + the capgo console service
docker-compose.override.yml   Capgo changes to upstream Supabase services
supabase/                     unmodified upstream supabase/docker (self-hosted/v0.8.2)
```

`supabase/` is a copy of [supabase/docker](https://github.com/supabase/supabase/tree/master/docker)
and is not edited by hand (the only local change is one line in `supabase/.gitignore`).
All customizations live in `docker-compose.override.yml`, which `docker compose` loads
automatically. Relative paths in it resolve from the repository root.

## Configuration

| File | Purpose |
| --- | --- |
| `supabase/.env` | Supabase stack: secrets, ports, URLs (`sh supabase/run.sh secrets` prints them) |
| `supabase/volumes/functions/.env` | Capgo Edge Functions (template: `capgo/supabase/functions/.env.example`) |
| `capgo-docker/.env` | Capgo console, baked in at image build time (template: `capgo-docker/env.example`) |

Storage S3 endpoint for Capgo: `S3_ENDPOINT=localhost:8000/storage/v1/s3`, keys =
`S3_PROTOCOL_ACCESS_KEY_ID` / `S3_PROTOCOL_ACCESS_KEY_SECRET` from `supabase/.env`.

## Setup from scratch

```sh
git submodule update --init
sh scripts/sync-capgo-functions.sh

# Capgo console image
docker compose build capgo

docker compose up -d --wait

# Capgo migrations (Supabase CLI >= 2.109, Postgres 17)
cd capgo
export PGSSLMODE=disable
supabase db push --db-url "postgresql://postgres.<POOLER_TENANT_ID>:<POSTGRES_PASSWORD>@127.0.0.1:<POSTGRES_PORT>/postgres"
cd ..

# Admin user, RBAC catalog, vault secrets, unlimited plan
ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=... sh scripts/init-capgo.sh
```

Console: http://localhost:8084 · API: http://localhost:8000

`init-capgo.sh` is idempotent — re-run it after every Capgo update, since it re-syncs
the RBAC permissions catalog from `capgo/supabase/seed.sql`. It creates the admin via the
Auth admin API and registers it as platform admin, sets the vault secrets used by DB
triggers/queues (`db_url`, `apikey` = `API_SECRET` from the functions `.env`), creates
storage buckets and the unlimited plan, and installs a trigger that keeps every
organization on that plan.

## Commands

```sh
docker compose up -d --wait
docker compose down
docker compose logs -f functions

# realtime and imgproxy are disabled; to run them too:
docker compose --profile full up -d

# Full reset (keeps .env files)
docker compose --profile full down -v --remove-orphans
rm -rf supabase/volumes/db/data
```

## Production (single domain behind host nginx)

Example: everything on `https://updater.my.com` — the console on `/`, the Supabase API
on `/auth/v1`, `/rest/v1`, `/storage/v1`, `/functions/v1`. Host nginx terminates TLS
(see [deploy/nginx.conf](deploy/nginx.conf)); Studio is not exposed (use
`ssh -L 8000:127.0.0.1:8000 server`).

`docker-compose.prod.yml` binds all published ports to `127.0.0.1` — without it
Postgres and the pooler listen on all interfaces:

```sh
docker compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.prod.yml up -d --wait
```

Generate fresh secrets on the server:

```sh
sh supabase/utils/generate-keys.sh --update-env
sh supabase/utils/add-new-auth-keys.sh --update-env
```

`supabase/.env`:

```sh
SUPABASE_PUBLIC_URL=https://updater.my.com
API_EXTERNAL_URL=https://updater.my.com/auth/v1
SITE_URL=https://updater.my.com
ADDITIONAL_REDIRECT_URLS=https://updater.my.com/**
DISABLE_SIGNUP=true
# real SMTP (password reset, confirmations): SMTP_ADMIN_EMAIL, SMTP_HOST, SMTP_PORT,
# SMTP_USER, SMTP_PASS, SMTP_SENDER_NAME
```

`capgo-docker/.env` (baked in at build time — rebuild the image after changes):

```sh
# no ENV=local here: it switches the console to http://
BASE_DOMAIN=updater.my.com
SUPA_URL=https://updater.my.com
SUPA_ANON=<ANON_KEY from supabase/.env>
API_DOMAIN=updater.my.com/functions/v1
CAPTCHA_KEY=""
```

`supabase/volumes/functions/.env`:

```sh
S3_ENDPOINT=updater.my.com/storage/v1/s3   # public: devices download bundles via presigned URLs
S3_SSL=true
S3_REGION=<REGION from supabase/.env>
S3_ACCESS_KEY_ID=<S3_PROTOCOL_ACCESS_KEY_ID from supabase/.env>
S3_SECRET_ACCESS_KEY=<S3_PROTOCOL_ACCESS_KEY_SECRET from supabase/.env>
WEBAPP_URL=https://updater.my.com
API_SECRET=                                # empty: init-capgo.sh generates one
STRIPE_SECRET_KEY=                         # empty: billing disabled
```

Then follow [Setup from scratch](#setup-from-scratch), adding `-f docker-compose.prod.yml`
as above.

Apps (`capacitor.config`): `updateUrl: https://updater.my.com/functions/v1/updates`,
`statsUrl: .../functions/v1/stats`, `channelUrl: .../functions/v1/channel_self`.
CLI: `npx @capgo/cli ... --supa-host https://updater.my.com --supa-anon <ANON_KEY>`.

## Updating

```sh
# Capgo
git submodule update --remote --merge capgo
sh scripts/sync-capgo-functions.sh
docker compose build capgo && docker compose up -d capgo   # bump the image tag in docker-compose.yml
# then: supabase db push (see above) and scripts/init-capgo.sh

# Supabase
sh supabase/update.sh --dry-run
sh supabase/update.sh
docker compose pull && docker compose up -d --wait
```
