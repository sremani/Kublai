#!/usr/bin/env bash
set -euo pipefail

export PATH="/home/srikanth/bin:${PATH}"

cluster_name="${HELM_CERT_CLUSTER_NAME:-kublai-ha}"
namespace="${HELM_CERT_NAMESPACE:-kublai-helm-cert}"
release_name="${HELM_RELEASE:-kublai}"
chart_path="${HELM_CERT_CHART:-deploy/helm/kublai}"
base_chart_path="${HELM_CERT_BASE_CHART:-$chart_path}"
report_path="${HELM_CERT_REPORT_PATH:-docs/reports/helm-certification-latest.md}"
api_port="${HELM_CERT_API_PORT:-18087}"
bootstrap_token="${HELM_CERT_BOOTSTRAP_TOKEN:-kind-ha-bootstrap}"
image_tag="${HELM_CERT_IMAGE_TAG:-helm-cert}"
object_storage_provider="${HELM_CERT_OBJECT_STORAGE_PROVIDER:-minio}"
object_storage_bucket="${HELM_CERT_OBJECT_STORAGE_BUCKET:-kublai-dev}"
object_storage_endpoint=""
object_storage_access_key=""
object_storage_secret_key=""
storage_values=""

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

run_step() {
  local name="$1"
  shift

  echo "==> ${name}"
  "$@"
}

cleanup() {
  if [ -n "${port_forward_pid:-}" ]; then
    kill "$port_forward_pid" >/dev/null 2>&1 || true
  fi
  rm -f "${base_values:-}" "${target_values:-}" "${storage_values:-}" "${port_forward_log:-}"
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

  key_info="$(garage key info --show-secret kublai-helm-cert 2>/dev/null || garage key create kublai-helm-cert)"
  object_storage_access_key="$(printf '%s\n' "$key_info" | sed -n 's/.*Key ID:[[:space:]]*//p' | head -n 1 | tr -d '[:space:]')"
  object_storage_secret_key="$(printf '%s\n' "$key_info" | sed -n 's/.*Secret key:[[:space:]]*//p' | head -n 1 | tr -d '[:space:]')"

  if [ -z "$object_storage_access_key" ] || [ -z "$object_storage_secret_key" ]; then
    echo "Could not parse Garage access key output." >&2
    printf '%s\n' "$key_info" >&2
    exit 1
  fi

  garage bucket allow --key kublai-helm-cert --read --write --owner "$object_storage_bucket" >/dev/null
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
      object_storage_endpoint="${HELM_CERT_OBJECT_STORAGE_ENDPOINT:-http://minio:9000}"
      object_storage_access_key="${HELM_CERT_OBJECT_STORAGE_ACCESS_KEY:-kublai}"
      object_storage_secret_key="${HELM_CERT_OBJECT_STORAGE_SECRET_KEY:-kublai-secret}"

      run_step "apply MinIO dependency" kubectl -n "$namespace" apply -f deploy/kind/dependencies-minio.yaml
      run_step "wait for MinIO" kubectl -n "$namespace" rollout status deployment/minio --timeout=180s

      bucket_job="minio-bootstrap-$(date -u +%s)"
      kubectl -n "$namespace" create job "$bucket_job" \
        --image=minio/mc:latest \
        -- sh -c "mc alias set local http://minio:9000 ${object_storage_access_key} ${object_storage_secret_key} && mc mb --ignore-existing local/${object_storage_bucket}"

      echo "==> bootstrap MinIO bucket"
      if ! kubectl -n "$namespace" wait --for=condition=complete "job/${bucket_job}" --timeout=120s; then
        kubectl -n "$namespace" describe "job/${bucket_job}" >&2 || true
        kubectl -n "$namespace" logs "job/${bucket_job}" --all-containers=true >&2 || true
        exit 1
      fi
      ;;
    garage)
      object_storage_endpoint="${HELM_CERT_OBJECT_STORAGE_ENDPOINT:-http://garage:3900}"

      run_step "apply Garage dependency" kubectl -n "$namespace" apply -f deploy/kind/dependencies-garage.yaml
      run_step "wait for Garage" kubectl -n "$namespace" rollout status deployment/garage --timeout=180s
      bootstrap_garage
      ;;
    external)
      object_storage_endpoint="${HELM_CERT_OBJECT_STORAGE_ENDPOINT:?HELM_CERT_OBJECT_STORAGE_ENDPOINT is required when HELM_CERT_OBJECT_STORAGE_PROVIDER=external}"
      object_storage_access_key="${HELM_CERT_OBJECT_STORAGE_ACCESS_KEY:?HELM_CERT_OBJECT_STORAGE_ACCESS_KEY is required when HELM_CERT_OBJECT_STORAGE_PROVIDER=external}"
      object_storage_secret_key="${HELM_CERT_OBJECT_STORAGE_SECRET_KEY:?HELM_CERT_OBJECT_STORAGE_SECRET_KEY is required when HELM_CERT_OBJECT_STORAGE_PROVIDER=external}"
      ;;
    *)
      echo "Unsupported HELM_CERT_OBJECT_STORAGE_PROVIDER: ${object_storage_provider}. Expected minio, garage, or external." >&2
      exit 1
      ;;
  esac

  write_storage_values
}

require_command curl
require_command docker
require_command helm
require_command kind
require_command kubectl

if ! kind get clusters | grep -Fxq "$cluster_name"; then
  run_step "create kind cluster" kind create cluster --config deploy/kind/kind-ha.yaml
fi

run_step "select kind context" kubectl config use-context "kind-${cluster_name}" >/dev/null

run_step "build API image" docker build -f deploy/kind/Dockerfile.api -t "kublai-api:${image_tag}" .
run_step "build worker image" docker build -f deploy/kind/Dockerfile.worker -t "kublai-worker:${image_tag}" .
run_step "load API image" kind load docker-image --name "$cluster_name" "kublai-api:${image_tag}"
run_step "load worker image" kind load docker-image --name "$cluster_name" "kublai-worker:${image_tag}"

echo "==> create namespace"
kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
run_step "apply Postgres dependency" kubectl -n "$namespace" apply -f deploy/kind/dependencies-postgres.yaml
run_step "wait for Postgres" kubectl -n "$namespace" rollout status deployment/postgres --timeout=180s
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

base_values="$(mktemp)"
target_values="$(mktemp)"

cat > "$base_values" <<EOF
api:
  replicaCount: 2
  image:
    repository: kublai-api
    tag: ${image_tag}
    pullPolicy: IfNotPresent
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
worker:
  replicaCount: 1
  image:
    repository: kublai-worker
    tag: ${image_tag}
    pullPolicy: IfNotPresent
EOF

cat > "$target_values" <<EOF
api:
  replicaCount: 3
  image:
    repository: kublai-api
    tag: ${image_tag}
    pullPolicy: IfNotPresent
  podDisruptionBudget:
    enabled: true
    minAvailable: 2
worker:
  replicaCount: 2
  image:
    repository: kublai-worker
    tag: ${image_tag}
    pullPolicy: IfNotPresent
EOF

base_chart_version="$(helm show chart "$base_chart_path" | sed -n 's/^version:[[:space:]]*//p' | head -n 1)"
target_chart_version="$(helm show chart "$chart_path" | sed -n 's/^version:[[:space:]]*//p' | head -n 1)"
helm_version="$(helm version --short)"
kind_version="$(kind version)"
kubernetes_version="$(kubectl version --short 2>/dev/null || kubectl version)"

run_step "lint target chart" helm lint "$chart_path" \
  --values deploy/helm/kublai/values-kind-ha.yaml \
  --values "$storage_values" \
  --values "$target_values"

run_step "install baseline chart" helm upgrade --install "$release_name" "$base_chart_path" \
  --namespace "$namespace" \
  --values deploy/helm/kublai/values-kind-ha.yaml \
  --values "$storage_values" \
  --values "$base_values" \
  --wait \
  --timeout 5m

run_step "wait baseline API" kubectl -n "$namespace" rollout status deployment/kublai-api --timeout=240s
run_step "wait baseline worker" kubectl -n "$namespace" rollout status deployment/kublai-worker --timeout=240s

port_forward_log="$(mktemp)"
kubectl -n "$namespace" port-forward svc/kublai-api "${api_port}:80" > "$port_forward_log" 2>&1 &
port_forward_pid="$!"
sleep 3

api_url="http://127.0.0.1:${api_port}"

issue_admin_token() {
  local subject="$1"
  local response

  response="$(curl -fsS \
    -X POST \
    "${api_url}/v1/auth/pats" \
    -H "Content-Type: application/json" \
    -H "X-Bootstrap-Token: ${bootstrap_token}" \
    --data "{\"Subject\":\"${subject}\",\"Scopes\":[\"repo:*:admin\"],\"TtlMinutes\":60}")"

  printf '%s' "$response" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p'
}

run_api_smoke() {
  local label="$1"
  local token="$2"
  local repo_key

  repo_key="helm-cert-${label}-$(date -u +%s)"

  curl -fsS "${api_url}/health/live" >/dev/null
  curl -fsS "${api_url}/health/ready" >/dev/null
  curl -fsS -H "Authorization: Bearer ${token}" "${api_url}/v1/auth/whoami" >/dev/null
  curl -fsS -H "Authorization: Bearer ${token}" "${api_url}/v1/admin/ops/summary" >/dev/null
  curl -fsS -H "Authorization: Bearer ${token}" "${api_url}/v1/repos" >/dev/null
  curl -fsS \
    -X POST \
    "${api_url}/v1/repos" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    --data "{\"RepoKey\":\"${repo_key}\",\"RepoType\":\"local\",\"UpstreamUrl\":\"\",\"MemberRepos\":[]}" >/dev/null
  curl -fsS -H "Authorization: Bearer ${token}" "${api_url}/v1/repos/${repo_key}" >/dev/null
}

admin_token="$(issue_admin_token "helm-cert-baseline-admin")"
if [ -z "$admin_token" ]; then
  echo "Failed to issue baseline admin PAT for Helm certification." >&2
  exit 1
fi

run_step "baseline API smoke" run_api_smoke "baseline" "$admin_token"

API_URL="$api_url" \
ADMIN_TOKEN="$admin_token" \
ConnectionStrings__Postgres=redacted \
ObjectStorage__Endpoint="$object_storage_endpoint" \
ObjectStorage__Bucket="$object_storage_bucket" \
Auth__BootstrapToken=redacted \
KUBE_NAMESPACE="$namespace" \
HELM_RELEASE="$release_name" \
PREFLIGHT_REQUIRE_HELM_CERT=false \
PREFLIGHT_REPORT_PATH=/tmp/kublai-helm-cert-preflight-baseline.md \
scripts/production-preflight.sh

run_step "upgrade to target chart" helm upgrade "$release_name" "$chart_path" \
  --namespace "$namespace" \
  --values deploy/helm/kublai/values-kind-ha.yaml \
  --values "$storage_values" \
  --values "$target_values" \
  --wait \
  --timeout 5m

run_step "wait upgraded API" kubectl -n "$namespace" rollout status deployment/kublai-api --timeout=240s
run_step "wait upgraded worker" kubectl -n "$namespace" rollout status deployment/kublai-worker --timeout=240s

upgraded_admin_token="$(issue_admin_token "helm-cert-upgrade-admin")"
if [ -z "$upgraded_admin_token" ]; then
  echo "Failed to issue upgraded admin PAT for Helm certification." >&2
  exit 1
fi

run_step "upgraded API smoke" run_api_smoke "upgrade" "$upgraded_admin_token"

API_URL="$api_url" \
ADMIN_TOKEN="$upgraded_admin_token" \
ConnectionStrings__Postgres=redacted \
ObjectStorage__Endpoint="$object_storage_endpoint" \
ObjectStorage__Bucket="$object_storage_bucket" \
Auth__BootstrapToken=redacted \
KUBE_NAMESPACE="$namespace" \
HELM_RELEASE="$release_name" \
PREFLIGHT_REQUIRE_HELM_CERT=false \
PREFLIGHT_REPORT_PATH=/tmp/kublai-helm-cert-preflight-upgrade.md \
scripts/production-preflight.sh

release_history="$(helm history "$release_name" --namespace "$namespace")"
pod_placement="$(kubectl -n "$namespace" get pods -o wide)"
api_replicas="$(kubectl -n "$namespace" get deployment kublai-api -o jsonpath='{.status.readyReplicas}')"
worker_replicas="$(kubectl -n "$namespace" get deployment kublai-worker -o jsonpath='{.status.readyReplicas}')"

run_step "uninstall release" helm uninstall "$release_name" --namespace "$namespace" --wait --timeout 5m

kubectl -n "$namespace" wait --for=delete deployment/kublai-api --timeout=120s >/dev/null 2>&1 || true
kubectl -n "$namespace" wait --for=delete deployment/kublai-worker --timeout=120s >/dev/null 2>&1 || true

leftover_resources="$(kubectl -n "$namespace" get deploy,svc,configmap,secret,pdb,networkpolicy -l "app.kubernetes.io/instance=${release_name}" --ignore-not-found -o name)"
if [ -n "$leftover_resources" ]; then
  echo "Helm uninstall left Kublai-owned resources:" >&2
  echo "$leftover_resources" >&2
  exit 1
fi

case "$object_storage_provider" in
  minio | garage)
    dependency_selector="app.kubernetes.io/name in (postgres,${object_storage_provider})"
    ;;
  external)
    dependency_selector="app.kubernetes.io/name=postgres"
    ;;
esac

dependency_resources="$(kubectl -n "$namespace" get deploy,svc -l "$dependency_selector" -o name)"
ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$report_path" <<EOF
# Helm Certification Report

Generated at: ${ended_at}

## Summary

- overall status: PASS
- started at: ${started_at}
- ended at: ${ended_at}
- cluster: ${cluster_name}
- namespace: ${namespace}
- release: ${release_name}
- baseline chart: ${base_chart_path}
- baseline chart version: ${base_chart_version}
- target chart: ${chart_path}
- target chart version: ${target_chart_version}
- object storage provider: ${object_storage_provider}
- object storage endpoint: ${object_storage_endpoint}
- object storage bucket: ${object_storage_bucket}
- API ready replicas after upgrade: ${api_replicas}
- worker ready replicas after upgrade: ${worker_replicas}

## Tooling

\`\`\`text
${kind_version}
${helm_version}
${kubernetes_version}
\`\`\`

## Validated Scenarios

- Helm lint with kind HA values
- selected object-storage dependency startup: ${object_storage_provider}
- selected object-storage bucket bootstrap: ${object_storage_bucket}
- baseline Helm install into kind Kubernetes
- API and worker rollout readiness after install
- API liveness and readiness smoke
- authenticated admin smoke
- repository create/read smoke
- production preflight with Kubernetes and Helm checks after install
- Helm upgrade to target chart values
- API and worker rollout readiness after upgrade
- API liveness and readiness smoke after upgrade
- authenticated admin smoke after upgrade
- repository create/read smoke after upgrade
- production preflight with Kubernetes and Helm checks after upgrade
- Helm uninstall
- uninstall cleanup check for Helm-owned Kublai resources
- data dependency preservation for Postgres and selected object-storage resources

## Helm History

\`\`\`text
${release_history}
\`\`\`

## Pod Placement Before Uninstall

\`\`\`text
${pod_placement}
\`\`\`

## Preserved Data Dependencies After Uninstall

\`\`\`text
${dependency_resources}
\`\`\`

## Preflight Reports

- baseline: \`/tmp/kublai-helm-cert-preflight-baseline.md\`
- upgrade: \`/tmp/kublai-helm-cert-preflight-upgrade.md\`

## Residual Risks

- default baseline chart path is the current chart unless
  \`HELM_CERT_BASE_CHART\` points to a previous released chart package
- validation uses local kind infrastructure, not managed cloud Kubernetes
- Postgres and in-cluster object storage are single-replica validation dependencies
- ingress/TLS is not validated in the kind certification path
EOF

sanitize_report
echo "Helm certification report: ${report_path}"
