<div align="center">

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/supabase/supabase/3-self-hosted-deployment)

</div>

# Self-Hosted Supabase with Docker

This is the official Docker Compose setup for self-hosted Supabase. It provides a complete stack with all Supabase services running locally or on your infrastructure.

## Getting Started

Follow the detailed setup guide in our documentation: [Self-Hosting with Docker](https://supabase.com/docs/guides/self-hosting/docker)

The guide covers:
- Prerequisites (Git and Docker)
- Initial setup and configuration
- Securing your installation
- Accessing services
- Updating your instance

## What's Included

This Docker Compose configuration includes the following services:

- **[Studio](https://github.com/supabase/supabase/tree/master/apps/studio)** - A dashboard for managing your self-hosted Supabase project
- **[Envoy](https://www.envoyproxy.io/)** - API gateway (default; Kong is available as an optional override via `sh run.sh config add kong`)
- **[Auth](https://github.com/supabase/auth)** - JWT-based authentication API for user sign-ups, logins, and session management
- **[PostgREST](https://github.com/PostgREST/postgrest)** - Web server that turns your PostgreSQL database directly into a RESTful API
- **[Realtime](https://github.com/supabase/realtime)** - Elixir server that listens to PostgreSQL database changes and broadcasts them over websockets
- **[Storage](https://github.com/supabase/storage)** - RESTful API for managing files in S3, with Postgres handling permissions
- **[imgproxy](https://github.com/imgproxy/imgproxy)** - Fast and secure image processing server
- **[postgres-meta](https://github.com/supabase/postgres-meta)** - RESTful API for managing Postgres (fetch tables, add roles, run queries)
- **[PostgreSQL](https://github.com/supabase/postgres)** - Object-relational database with over 30 years of active development
- **[Edge Runtime](https://github.com/supabase/edge-runtime)** - Web server based on Deno runtime for running JavaScript, TypeScript, and WASM services
- **[Logflare](https://github.com/Logflare/logflare)** - Log management and event analytics platform
- **[Vector](https://github.com/vectordotdev/vector)** - High-performance observability data pipeline for logs
- **[Supavisor](https://github.com/supabase/supavisor)** - Supabase's Postgres connection pooler

## Documentation

- **[Self-Hosting with Docker](https://supabase.com/docs/guides/self-hosting/docker)** - Setup and configuration guides
- **[CHANGELOG.md](./CHANGELOG.md)** - Track recent updates and changes to services
- **[versions.md](./versions.md)** - Complete history of Docker image versions for rollback reference
- **[Ask DeepWiki / Supabase](https://deepwiki.com/supabase/supabase/3-self-hosted-deployment)** - DeepWiki-generated description of self-hosted configuration
- **[CONFIG.md](./CONFIG.md)** - Configuration reference for all environment variables
- **[Update your deployment](https://supabase.com/docs/guides/self-hosting/updating)** - Update an existing deployment with `update.sh`

## Updates

Back up your database, then:

```sh
sh update.sh --dry-run   # optional preview
sh update.sh
sh run.sh pull && sh run.sh recreate
```

See the **[update guide](https://supabase.com/docs/guides/self-hosting/updating)** for conflicts,
breaking changes, pinning a release, and older installs without `.supabase-version`.

## Community & Support

For troubleshooting common issues, see:
- [GitHub Discussions](https://github.com/orgs/supabase/discussions?discussions_q=is%3Aopen+label%3Aself-hosted) - Questions, feature requests, and workarounds
- [GitHub Issues](https://github.com/supabase/supabase/issues?q=is%3Aissue%20state%3Aopen%20label%3Aself-hosted) - Known issues
- [Documentation](https://supabase.com/docs/guides/self-hosting) - Setup and configuration guides

Self-hosted Supabase is community-supported. Get help and connect with other users:

- [Discord](https://discord.supabase.com) - Real-time chat and community support
- [Reddit](https://www.reddit.com/r/Supabase/) - Official Supabase subreddit

Share your self-hosting experience:

- [GitHub Discussions](https://github.com/orgs/supabase/discussions/39820) - "Self-hosting: What's working (and what's not)?"

## Important Notes

### Security

⚠️ **The default configuration is not secure for production use.**

Before deploying to production, you must:
- [Update](https://supabase.com/docs/guides/self-hosting/docker#configuring-and-securing-supabase) all default passwords and secrets in the `.env` file
- Review and update CORS settings
- Set up a [secure proxy](https://supabase.com/docs/guides/self-hosting/self-hosted-proxy-https) in front of your self-hosted Supabase
- Review and adjust network security configuration (ACLs, etc.)
- Set up proper backup procedures

See the [main installation guide](https://supabase.com/docs/guides/self-hosting/docker) and the how-tos in the documentation.

## License

This repository is licensed under the Apache 2.0 License. See the main [Supabase repository](https://github.com/supabase/supabase) for details.

---

## Capgo Integration

Based on upstream `self-hosted/v0.8.2` (see `.supabase-version`). Upstream files are kept
unmodified; everything Capgo-specific lives in `docker-compose.capgo.yml`, enabled through
`COMPOSE_FILE` in `.env`. Update the Supabase part with `sh update.sh`.

Capgo is a git submodule. To update it and sync the Edge Functions into `volumes/functions`:

```sh
git submodule update --init --remote --merge
sh ./scripts/sync-capgo-functions.sh
```

Edge Functions read `volumes/functions/.env` (template: `capgo/supabase/functions/.env.example`).
Storage S3 endpoint for Capgo is `S3_ENDPOINT=localhost:8000/storage/v1/s3` with
`S3_PROTOCOL_ACCESS_KEY_ID` / `S3_PROTOCOL_ACCESS_KEY_SECRET` from `.env`.

### Commands

```sh
# Build the Capgo console image (capgo-docker/.env is baked in at build time)
docker build -f ./capgo-docker/Dockerfile --tag capgo:12.312.0 .

sh run.sh start       # docker compose up -d --wait
sh run.sh stop
sh run.sh secrets     # print keys and passwords from .env

# realtime and imgproxy are disabled; to run them too:
docker compose --profile full up -d
```

### Capgo migrations

Requires Supabase CLI >= 2.109 and Postgres 17.

```sh
cd capgo
export PGSSLMODE=disable
supabase db push --db-url "postgresql://postgres.<POOLER_TENANT_ID>:<POSTGRES_PASSWORD>@127.0.0.1:<POSTGRES_PORT>/postgres"
```

### Bootstrap (admin user, RBAC, unlimited plan)

Run after the migrations. Idempotent — re-run after every capgo update, since it
re-syncs the RBAC permissions catalog from `capgo/supabase/seed.sql`.

```sh
ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=... sh scripts/init-capgo.sh
```

It creates the admin via the Auth admin API and registers it as platform admin,
sets the vault secrets used by DB triggers/queues (`db_url`, `apikey` = `API_SECRET`
from `volumes/functions/.env`), creates storage buckets and the unlimited plan, and
installs a trigger that keeps every organization on that plan.
