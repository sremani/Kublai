# Upgrade Compatibility Drill Report

Generated at: 2026-05-17T01:48:12Z

## Summary

- overall status: PASS
- total duration (seconds): 13

## Release Artifact Inputs

- release tag: `v0.1.0-rc.2`
- API image digest: `ghcr.io/sremani/kublai-api@sha256:6f732dbc6341b311bf12557c31dc8f84fa7ba8b9db74d83da2c169fbb062b021`
- worker image digest: `ghcr.io/sremani/kublai-worker@sha256:ff4f6f47d6b5c70311c928e19950588579b63ffa8b6969c41f193c46d130e6a8`
- Helm chart digest: `sha256:652375c5114b00fa8a9bd262fcca2b033d9f7f729405934a434e5f199c82ddba`
- SBOM path: `artifacts/release-provenance/v0.1.0-rc.2/kublai-helm-chart.sbom.cdx.json`
- release provenance report: `docs/reports/release-provenance-latest.md`

## Rehearsed Paths

- PASS: Phase 6 GA baseline -> head from 0009_post_ga_search_read_model.sql
- PASS: Enterprise identity and reliability baseline -> head from 0010_enterprise_identity_and_reliability.sql
- PASS: Tenant delegation and audit correlation baseline -> head from 0012_tenant_role_bindings_and_audit_correlation.sql
