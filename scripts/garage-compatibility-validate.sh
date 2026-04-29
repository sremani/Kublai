#!/usr/bin/env bash
set -euo pipefail

compose_project="${GARAGE_COMPOSE_PROJECT:-kublai-garage}"
compose_file="${GARAGE_COMPOSE_FILE:-docker-compose.garage.yml}"
bucket_name="${GARAGE_BUCKET:-kublai-garage-compat}"
key_name="${GARAGE_KEY_NAME:-kublai-garage-compat}"
endpoint="${GARAGE_ENDPOINT:-http://127.0.0.1:3900}"
capacity="${GARAGE_LAYOUT_CAPACITY:-1G}"
zone="${GARAGE_LAYOUT_ZONE:-dc1}"
configuration="${CONFIGURATION:-Debug}"
report_path="${GARAGE_COMPAT_REPORT_PATH:-docs/reports/garage-compatibility-latest.md}"
test_filter="${GARAGE_COMPAT_TEST_FILTER:-FullyQualifiedName~Object storage provider contract|FullyQualifiedName~Object storage client supports multipart upload and ranged download}"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

garage() {
  docker compose -p "$compose_project" -f "$compose_file" exec -T garage /garage "$@"
}

wait_for_garage() {
  for attempt in $(seq 1 60); do
    if garage status >/dev/null 2>&1; then
      echo "Garage is ready."
      return 0
    fi

    echo "Waiting for Garage ($attempt/60)..."
    sleep 2
  done

  echo "Garage did not become ready in time." >&2
  docker compose -p "$compose_project" -f "$compose_file" logs garage >&2 || true
  return 1
}

find_node_id() {
  local node_id

  node_id="$(garage node id 2>/dev/null | sed -n '1s/@.*//p' | tr -d '[:space:]' || true)"
  if [ -n "$node_id" ]; then
    printf '%s\n' "$node_id"
    return 0
  fi

  garage status | awk '
    /^[[:space:]]*[0-9a-f]{16,64}/ {
      node = $1
      sub(/@.*/, "", node)
      print node
      exit
    }'
}

ensure_layout() {
  local node_id
  local current_version
  local next_version
  node_id="$(find_node_id)"

  if [ -z "$node_id" ]; then
    echo "Could not determine Garage node id." >&2
    garage status >&2 || true
    return 1
  fi

  if garage status | grep -q "NO ROLE ASSIGNED"; then
    current_version="$(garage layout show | sed -n 's/^Current cluster layout version:[[:space:]]*//p' | tail -n 1)"
    next_version="$((current_version + 1))"

    garage layout assign -z "$zone" -c "$capacity" "$node_id" >/dev/null
    garage layout apply --version "$next_version" >/dev/null
  fi
}

ensure_bucket() {
  if ! garage bucket info "$bucket_name" >/dev/null 2>&1; then
    garage bucket create "$bucket_name" >/dev/null
  fi
}

ensure_key() {
  local key_info
  local access_key
  local secret_key

  key_info="$(garage key info --show-secret "$key_name" 2>/dev/null || garage key create "$key_name")"
  access_key="$(printf '%s\n' "$key_info" | sed -n 's/^[[:space:]]*Key ID:[[:space:]]*//p' | head -n 1)"
  secret_key="$(printf '%s\n' "$key_info" | sed -n 's/^[[:space:]]*Secret key:[[:space:]]*//p' | head -n 1)"

  if [ -z "$access_key" ] || [ -z "$secret_key" ]; then
    echo "Could not parse Garage access key output." >&2
    printf '%s\n' "$key_info" >&2
    return 1
  fi

  garage bucket allow --key "$key_name" --read --write --owner "$bucket_name" >/dev/null

  export ObjectStorage__Endpoint="$endpoint"
  export ObjectStorage__AccessKey="$access_key"
  export ObjectStorage__SecretKey="$secret_key"
  export ObjectStorage__Bucket="$bucket_name"
}

docker compose -p "$compose_project" -f "$compose_file" up -d
wait_for_garage
ensure_layout
ensure_bucket
ensure_key

echo "Running Kublai object-storage compatibility test against Garage at $endpoint."
if dotnet test tests/Kublai.Domain.Tests/Kublai.Domain.Tests.fsproj \
  --configuration "$configuration" \
  -v minimal \
  --filter "$test_filter"; then
  result="PASS"
else
  result="FAIL"
fi

ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$(dirname "$report_path")"

cat > "$report_path" <<EOF
# Garage Compatibility Report

Generated at: ${ended_at}

## Summary

- Result: ${result}
- Started at: ${started_at}
- Completed at: ${ended_at}
- Endpoint: ${endpoint}
- Bucket: ${bucket_name}
- Garage image: ${GARAGE_IMAGE:-dxflrs/garage:v2.3.0}
- Test filter: ${test_filter}

## Coverage

- Garage single-node layout bootstrap
- Garage bucket creation
- Garage access key creation
- Bucket read/write/owner permission grant
- Provider availability check
- Missing-object NotFound mapping
- Invalid-range mapping
- Delete semantics
- Incomplete multipart upload abort semantics
- Object metadata and ETag behavior
- Kublai multipart upload start
- Presigned upload part PUT
- Multipart upload complete
- Full object download
- Ranged object download

## Remaining EGA-35 Gates

- Add backup/restore procedure for Garage metadata and data volumes.
- Document AGPLv3 distribution obligations before adopting Garage in supported
  release artifacts.
- Add kind and Helm dependency options after local compatibility remains stable.
EOF

if [ "$result" != "PASS" ]; then
  exit 1
fi
