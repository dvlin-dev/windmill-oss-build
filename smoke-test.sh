#!/usr/bin/env bash
# Smoke test for a freshly built image. Fails (non-zero) unless:
#   - the server starts against a throwaway PostgreSQL,
#   - /api/version reports the pinned upstream tag,
#   - an unauthenticated API call is rejected with 401 (no_auth not compiled in).
set -euo pipefail

IMAGE="$1"
EXPECTED_TAG="$2"   # e.g. v1.839.0
NET="wm-smoke-$$"

cleanup() {
  docker rm -f "$NET-app" "$NET-db" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$NET" >/dev/null
docker run -d --name "$NET-db" --network "$NET" \
  -e POSTGRES_PASSWORD=smoke -e POSTGRES_DB=windmill postgres:16 >/dev/null

for _ in $(seq 1 30); do
  docker exec "$NET-db" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 2
done

docker run -d --name "$NET-app" --network "$NET" -p 127.0.0.1:18000:8000 \
  -e DATABASE_URL="postgres://postgres:smoke@$NET-db/windmill?sslmode=disable" \
  -e MODE=server "$IMAGE" >/dev/null

version=""
for _ in $(seq 1 90); do
  version=$(curl -fsS http://127.0.0.1:18000/api/version 2>/dev/null || true)
  [ -n "$version" ] && break
  sleep 2
done

if [ -z "$version" ]; then
  echo "server did not answer /api/version"
  docker logs "$NET-app" 2>&1 | tail -50
  exit 1
fi
echo "version: $version"

case "$version" in
  *"${EXPECTED_TAG#v}"*) ;;
  *) echo "version does not contain $EXPECTED_TAG"; exit 1 ;;
esac
case "$version" in
  *EE*) echo "enterprise build detected"; exit 1 ;;
esac

code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18000/api/users/whoami)
echo "unauthenticated whoami: $code"
[ "$code" = "401" ] || { echo "expected 401, got $code (no_auth compiled in?)"; exit 1; }

echo "smoke test passed"
