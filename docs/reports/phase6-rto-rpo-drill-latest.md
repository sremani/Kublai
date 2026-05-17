# Phase 6 RPO/RTO Drill Report

Generated at: 2026-05-17T01:47:30Z

## Inputs

- source DB: `kublai`
- drill DB: `kublai_drill`
- backup file: `/tmp/kublai-phase6-drill-20260516-204728.sql`
- RTO target (seconds): 900
- RPO target (seconds): 300

## Release Artifact Inputs

- release tag: `v0.1.0-rc.2`
- API image digest: `ghcr.io/sremani/kublai-api@sha256:6f732dbc6341b311bf12557c31dc8f84fa7ba8b9db74d83da2c169fbb062b021`
- worker image digest: `ghcr.io/sremani/kublai-worker@sha256:ff4f6f47d6b5c70311c928e19950588579b63ffa8b6969c41f193c46d130e6a8`
- Helm chart digest: `sha256:652375c5114b00fa8a9bd262fcca2b033d9f7f729405934a434e5f199c82ddba`
- SBOM path: `artifacts/release-provenance/v0.1.0-rc.2/kublai-helm-chart.sbom.cdx.json`
- release provenance report: `docs/reports/release-provenance-latest.md`

## Results

- backup duration (seconds): 0
- restore duration (seconds): 1
- total drill duration (seconds): 2
- RPO status: PASS
- RTO status: PASS
- data verification: PASS

## Verification Notes

- all required table counts matched between source and drill databases.
