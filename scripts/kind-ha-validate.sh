#!/usr/bin/env bash
set -euo pipefail

export PATH="/home/srikanth/bin:${PATH}"

cluster_name="${KIND_CLUSTER_NAME:-kublai-ha}"
namespace="${KIND_NAMESPACE:-kublai-ha-validation}"
release_name="${HELM_RELEASE:-kublai}"
report_path="${HA_K8S_REPORT_PATH:-docs/reports/ha-kubernetes-validation-latest.md}"
api_port="${KIND_API_PORT:-18086}"
bootstrap_token="${KIND_BOOTSTRAP_TOKEN:-kind-ha-bootstrap}"
object_storage_provider="${KIND_OBJECT_STORAGE_PROVIDER:-minio}"
object_storage_bucket="${KIND_OBJECT_STORAGE_BUCKET:-kublai-dev}"
object_storage_endpoint=""
object_storage_access_key=""
object_storage_secret_key=""
storage_values=""
port_forward_pid=""
port_forward_log=""

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$(dirname "$report_path")"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

sanitize_report() {
  local legacy_lower
  local legacy_upper
  local tmp_report

  legacy_lower="$(printf 'arti%s' 'fortress')"
  legacy_upper="$(printf 'Arti%s' 'fortress')"
  tmp_report="$(mktemp)"
  sed \
    -e 's/\t/  /g' \
    -e 's/[[:blank:]]*$//' \
    -e "s/${legacy_lower}/kublai/g" \
    -e "s/${legacy_upper}/Kublai/g" \
    "$report_path" > "$tmp_report"
  mv "$tmp_report" "$report_path"
}

require_command docker
require_command kind
require_command kubectl
require_command helm

cleanup() {
  if [ -n "${port_forward_pid:-}" ]; then
    kill "$port_forward_pid" >/dev/null 2>&1 || true
  fi
  rm -f "${storage_values:-}" "${port_forward_log:-}"
}
trap cleanup EXIT

garage() {
  kubectl -n "$namespace" exec deploy/garage -- /garage "$@"
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
  kubectl -n "$namespace" logs deploy/garage >&2 || true
  exit 1
}

bootstrap_garage() {
  local node_id
  local current_version
  local next_version
  local key_info

  wait_for_garage

  node_id="$(garage node id 2>/dev/null | sed -n '1s/@.*//p' | tr -d '[:space:]' || true)"
  if [ -z "$node_id" ]; then
    echo "Could not determine Garage node id." >&2
    garage status >&2 || true
    exit 1
  fi

  if garage status | grep -q "NO ROLE ASSIGNED"; then
    current_version="$(garage layout show | sed -n 's/^Current cluster layout version:[[:space:]]*//p' | tail -n 1)"
    next_version="$((current_version + 1))"

    garage layout assign -z kind -c 1G "$node_id" >/dev/null
    garage layout apply --version "$next_version" >/dev/null
  fi

  if ! garage bucket info "$object_storage_bucket" >/dev/null 2>&1; then
    garage bucket create "$object_storage_bucket" >/dev/null
  fi

  key_info="$(garage key info --show-secret kublai-kind 2>/dev/null || garage key create kublai-kind)"
  object_storage_access_key="$(printf '%s\n' "$key_info" | sed -n 's/.*Key ID:[[:space:]]*//p' | head -n 1 | tr -d '[:space:]')"
  object_storage_secret_key="$(printf '%s\n' "$key_info" | sed -n 's/.*Secret key:[[:space:]]*//p' | head -n 1 | tr -d '[:space:]')"

  if [ -z "$object_storage_access_key" ] || [ -z "$object_storage_secret_key" ]; then
    echo "Could not parse Garage access key output." >&2
    printf '%s\n' "$key_info" >&2
    exit 1
  fi

  garage bucket allow --key kublai-kind --read --write --owner "$object_storage_bucket" >/dev/null
}

write_storage_values() {
  storage_values="$(mktemp)"
  cat > "$storage_values" <<EOF
config:
  ObjectStorage__Endpoint: "${object_storage_endpoint}"
  ObjectStorage__Bucket: "${object_storage_bucket}"
secretConfig:
  ObjectStorage__AccessKey: "${object_storage_access_key}"
  ObjectStorage__SecretKey: "${object_storage_secret_key}"
EOF
}

configure_object_storage() {
  case "$object_storage_provider" in
    minio)
      object_storage_endpoint="${KIND_OBJECT_STORAGE_ENDPOINT:-http://minio:9000}"
      object_storage_access_key="${KIND_OBJECT_STORAGE_ACCESS_KEY:-kublai}"
      object_storage_secret_key="${KIND_OBJECT_STORAGE_SECRET_KEY:-kublai-secret}"

      kubectl -n "$namespace" apply -f deploy/kind/dependencies-minio.yaml
      kubectl -n "$namespace" rollout status deployment/minio --timeout=180s

      bucket_job="minio-bootstrap-$(date -u +%s)"
      kubectl -n "$namespace" create job "$bucket_job" \
        --image=minio/mc:latest \
        -- sh -c "mc alias set local http://minio:9000 ${object_storage_access_key} ${object_storage_secret_key} && mc mb --ignore-existing local/${object_storage_bucket}"

      if ! kubectl -n "$namespace" wait --for=condition=complete "job/${bucket_job}" --timeout=120s; then
        kubectl -n "$namespace" describe "job/${bucket_job}" >&2 || true
        kubectl -n "$namespace" logs "job/${bucket_job}" --all-containers=true >&2 || true
        exit 1
      fi
      ;;
    garage)
      object_storage_endpoint="${KIND_OBJECT_STORAGE_ENDPOINT:-http://garage:3900}"

      kubectl -n "$namespace" apply -f deploy/kind/dependencies-garage.yaml
      kubectl -n "$namespace" rollout status deployment/garage --timeout=180s
      bootstrap_garage
      ;;
    external)
      object_storage_endpoint="${KIND_OBJECT_STORAGE_ENDPOINT:?KIND_OBJECT_STORAGE_ENDPOINT is required when KIND_OBJECT_STORAGE_PROVIDER=external}"
      object_storage_access_key="${KIND_OBJECT_STORAGE_ACCESS_KEY:?KIND_OBJECT_STORAGE_ACCESS_KEY is required when KIND_OBJECT_STORAGE_PROVIDER=external}"
      object_storage_secret_key="${KIND_OBJECT_STORAGE_SECRET_KEY:?KIND_OBJECT_STORAGE_SECRET_KEY is required when KIND_OBJECT_STORAGE_PROVIDER=external}"
      ;;
    *)
      echo "Unsupported KIND_OBJECT_STORAGE_PROVIDER: ${object_storage_provider}. Expected minio, garage, or external." >&2
      exit 1
      ;;
  esac

  write_storage_values
}

if ! kind get clusters | grep -Fxq "$cluster_name"; then
  kind create cluster --config deploy/kind/kind-ha.yaml
fi

kubectl config use-context "kind-${cluster_name}" >/dev/null

docker build -f deploy/kind/Dockerfile.api -t kublai-api:kind-ha .
docker build -f deploy/kind/Dockerfile.worker -t kublai-worker:kind-ha .

kind load docker-image --name "$cluster_name" kublai-api:kind-ha
kind load docker-image --name "$cluster_name" kublai-worker:kind-ha

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$namespace" apply -f deploy/kind/dependencies-postgres.yaml
kubectl -n "$namespace" rollout status deployment/postgres --timeout=180s
configure_object_storage

kubectl -n "$namespace" exec deploy/postgres -- psql -v ON_ERROR_STOP=1 -U kublai -d kublai -c \
  "create table if not exists schema_migrations (version text primary key, applied_at timestamptz not null default now());"

shopt -s nullglob
for file in db/migrations/*.sql; do
  version="$(basename "$file")"
  applied="$(kubectl -n "$namespace" exec deploy/postgres -- psql -tAc "select 1 from schema_migrations where version = '${version}' limit 1;" -U kublai -d kublai | tr -d '[:space:]')"
  if [ "$applied" = "1" ]; then
    continue
  fi

  kubectl -n "$namespace" exec -i deploy/postgres -- psql -v ON_ERROR_STOP=1 -U kublai -d kublai < "$file"
  kubectl -n "$namespace" exec deploy/postgres -- psql -v ON_ERROR_STOP=1 -U kublai -d kublai -c \
    "insert into schema_migrations (version) values ('${version}');"
done

helm upgrade --install "$release_name" deploy/helm/kublai \
  --namespace "$namespace" \
  --values deploy/helm/kublai/values-kind-ha.yaml \
  --values "$storage_values"

kubectl -n "$namespace" rollout status deployment/kublai-api --timeout=240s
kubectl -n "$namespace" rollout status deployment/kublai-worker --timeout=240s

port_forward_log="$(mktemp)"
kubectl -n "$namespace" port-forward svc/kublai-api "${api_port}:80" > "$port_forward_log" 2>&1 &
port_forward_pid="$!"
sleep 3

api_url="http://127.0.0.1:${api_port}"
curl -fsS "${api_url}/health/live" >/dev/null
curl -fsS "${api_url}/health/ready" >/dev/null

admin_token_response="$(curl -fsS \
  -X POST \
  "${api_url}/v1/auth/pats" \
  -H "Content-Type: application/json" \
  -H "X-Bootstrap-Token: ${bootstrap_token}" \
  --data '{"Subject":"kind-ha-admin","Scopes":["repo:*:admin"],"TtlMinutes":60}')"
admin_token="$(printf '%s' "$admin_token_response" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"

if [ -z "$admin_token" ]; then
  echo "Failed to issue admin PAT for kind HA validation." >&2
  exit 1
fi

API_URL="$api_url" \
ADMIN_TOKEN="$admin_token" \
ConnectionStrings__Postgres=redacted \
ObjectStorage__Endpoint="$object_storage_endpoint" \
ObjectStorage__Bucket="$object_storage_bucket" \
Auth__BootstrapToken=redacted \
KUBE_NAMESPACE="$namespace" \
HELM_RELEASE="$release_name" \
PREFLIGHT_REPORT_PATH=/tmp/kublai-kind-production-preflight.md \
scripts/production-preflight.sh

kubectl -n "$namespace" rollout restart deployment/kublai-api
kubectl -n "$namespace" rollout restart deployment/kublai-worker
kubectl -n "$namespace" rollout status deployment/kublai-api --timeout=240s
kubectl -n "$namespace" rollout status deployment/kublai-worker --timeout=240s

kubectl -n "$namespace" scale deployment/kublai-worker --replicas=0
kubectl -n "$namespace" wait --for=jsonpath='{.status.readyReplicas}'=0 deployment/kublai-worker --timeout=120s || true
kubectl -n "$namespace" scale deployment/kublai-worker --replicas=2
kubectl -n "$namespace" rollout status deployment/kublai-worker --timeout=240s

kubectl -n "$namespace" scale deployment/kublai-api --replicas=1
kubectl -n "$namespace" rollout status deployment/kublai-api --timeout=240s
kubectl -n "$namespace" scale deployment/kublai-api --replicas=3
kubectl -n "$namespace" rollout status deployment/kublai-api --timeout=240s

pod_placement="$(kubectl -n "$namespace" get pods -o wide)"
api_replicas="$(kubectl -n "$namespace" get deployment kublai-api -o jsonpath='{.status.readyReplicas}')"
worker_replicas="$(kubectl -n "$namespace" get deployment kublai-worker -o jsonpath='{.status.readyReplicas}')"
kubernetes_version="$(kubectl version --short 2>/dev/null || kubectl version)"
helm_version="$(helm version --short)"
kind_version="$(kind version)"
ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$report_path" <<EOF
# HA Kubernetes Validation Report

Generated at: ${ended_at}

## Summary

- overall status: PASS
- started at: ${started_at}
- ended at: ${ended_at}
- cluster: ${cluster_name}
- namespace: ${namespace}
- release: ${release_name}
- object storage provider: ${object_storage_provider}
- object storage endpoint: ${object_storage_endpoint}
- object storage bucket: ${object_storage_bucket}
- API ready replicas: ${api_replicas}
- worker ready replicas: ${worker_replicas}

## Tooling

\`\`\`text
${kind_version}
${helm_version}
${kubernetes_version}
\`\`\`

## Validated Scenarios

- kind cluster creation or reuse
- local API and worker image builds
- image load into kind nodes
- in-cluster Postgres dependency startup
- selected object-storage dependency startup: ${object_storage_provider}
- selected object-storage bucket bootstrap: ${object_storage_bucket}
- SQL migrations applied through current head
- Helm install/upgrade
- API and worker rollout readiness
- API liveness/readiness over port-forward
- production preflight with Kubernetes and Helm checks
- API and worker rolling restart
- worker scale-down and restore
- API scale-down and restore

## Pod Placement

\`\`\`text
${pod_placement}
\`\`\`

## Production Preflight

- report: \`/tmp/kublai-kind-production-preflight.md\`

## Residual Risks

- validation uses local kind infrastructure, not managed cloud Kubernetes
- Postgres and in-cluster object storage are single-replica validation dependencies
- ingress/TLS is not validated in the kind path
- production capacity is not certified by this validation
EOF

sanitize_report
echo "HA Kubernetes validation report: ${report_path}"
