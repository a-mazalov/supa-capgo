FROM oven/bun:1.3 AS build
WORKDIR /app

# Deps
COPY ../capgo/package.json ../capgo/bun.* ../capgo/bunfig.* ./
RUN bun install --frozen-lockfile

# Build
COPY ../capgo .
COPY ./capgo-docker/.env .

RUN bun run build

# Runtime
FROM nginx:1.25-alpine AS runtime
WORKDIR /usr/share/nginx/html

COPY --from=build /app/dist/ ./

COPY ./capgo-docker/nginx.default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
