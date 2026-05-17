# Production Preflight Report

Generated at: 2026-05-17T02:03:57Z

## Results

| Check | Status | Detail |
|---|---|---|
| README.md | PASS | file exists |
| Makefile | PASS | file exists |
| docker-compose.yml | PASS | file exists |
| deploy/enterprise-ops-alert-thresholds.yaml | PASS | file exists |
| deploy/grafana-kublai-operations-dashboard.json | PASS | file exists |
| deploy/helm/kublai | PASS | directory exists |
| deploy/kubernetes/production | PASS | directory exists |
| docs/59-enterprise-product-envelope.md | PASS | file exists |
| docs/60-versioning-support-policy.md | PASS | file exists |
| docs/61-release-candidate-signoff.md | PASS | file exists |
| docs/68-slo-sli-alerting.md | PASS | file exists |
| docs/69-ha-kubernetes-validation-plan.md | PASS | file exists |
| docs/70-production-preflight.md | PASS | file exists |
| docs/reports/enterprise-verification-latest.md | PASS | file exists |
| docs/reports/phase6-rto-rpo-drill-latest.md | PASS | file exists |
| docs/reports/upgrade-compatibility-drill-latest.md | PASS | file exists |
| docs/reports/reliability-drill-latest.md | PASS | file exists |
| docs/reports/helm-certification-latest.md | PASS | file exists |
| API_URL | PASS | configured |
| ADMIN_TOKEN | PASS | configured |
| ConnectionStrings__Postgres | PASS | configured |
| ObjectStorage__Endpoint | PASS | configured |
| ObjectStorage__Bucket | PASS | configured |
| Auth__BootstrapToken | PASS | configured |
| ASPNETCORE_ENVIRONMENT | PASS | configured |
| ObjectStorage__AccessKey | PASS | configured |
| ObjectStorage__SecretKey | PASS | configured |
| Auth__Oidc__Issuer | PASS | configured |
| Auth__Oidc__Audience | PASS | configured |
| OIDC signing material | PASS | at least one signing mode configured |
| Auth__Saml__ExpectedIssuer | PASS | configured |
| Auth__Saml__ServiceProviderEntityId | PASS | configured |
| SAML metadata | PASS | metadata source configured |
| /health/live | PASS | endpoint responded |
| /health/ready | PASS | status is ready |
| /v1/admin/ops/summary | PASS | endpoint responded |
| ingress TLS | PASS | API_URL uses HTTPS |
| kubernetes api deployment | PASS | kublai-api deployment exists |
| kubernetes worker deployment | PASS | kublai-worker deployment exists |
| helm release | PASS | release status is available |

## Summary

- overall status: PASS
- started at: 2026-05-17T02:03:57Z
- ended at: 2026-05-17T02:03:57Z
- pass count: 40
- warning count: 0
- failure count: 0
