# Release Provenance Evidence

Generated at: 2026-05-17T02:14:01Z

## Summary

- overall status: PASS
- tag: v0.1.0-rc.3
- version: 0.1.0-rc.3
- tag subject: Kublai v0.1.0-rc.3
- tag commit: 3b871db75713b77b40a11158ee2fbb3a74c0389c
- asset directory: `/home/srikanth/projects/Kublai/artifacts/release-provenance/v0.1.0-rc.3`
- started at: 2026-05-17T02:13:53Z
- ended at: 2026-05-17T02:14:01Z
- total duration seconds: 8

## Verified OCI Images

- API: `ghcr.io/sremani/kublai-api@sha256:3b02e3f3675527edce065031c8104425188e254cbf60d27392f00dfc75b52460`
- Worker: `ghcr.io/sremani/kublai-worker@sha256:4dd99300a1cefae123e7d5bcd415088df386b4b8391bd58247ac9263cdaff904`

## Verification Steps

| Step | Command | Status | Duration Seconds | Log |
|---|---|---:|---:|---|
| fetch release tag | `cd '/home/srikanth/projects/Kublai' && git fetch origin 'refs/tags/v0.1.0-rc.3:refs/tags/v0.1.0-rc.3'` | PASS | 1 | `artifacts/release-provenance/v0.1.0-rc.3/fetch-release-tag.log` |
| verify signed git tag | `cd '/home/srikanth/projects/Kublai' && git verify-tag 'v0.1.0-rc.3'` | PASS | 0 | `artifacts/release-provenance/v0.1.0-rc.3/verify-signed-git-tag.log` |
| check remote tag | `cd '/home/srikanth/projects/Kublai' && git ls-remote --exit-code --tags origin 'refs/tags/v0.1.0-rc.3'` | PASS | 1 | `artifacts/release-provenance/v0.1.0-rc.3/check-remote-tag.log` |
| check GitHub release | `cd '/home/srikanth/projects/Kublai' && gh release view 'v0.1.0-rc.3'` | PASS | 0 | `artifacts/release-provenance/v0.1.0-rc.3/check-GitHub-release.log` |
| download release assets | `cd '/home/srikanth/projects/Kublai' && gh release download 'v0.1.0-rc.3' --dir '/home/srikanth/projects/Kublai/artifacts/release-provenance/v0.1.0-rc.3' --clobber` | PASS | 2 | `artifacts/release-provenance/v0.1.0-rc.3/download-release-assets.log` |
| verify checksums | `cd '/home/srikanth/projects/Kublai/artifacts/release-provenance/v0.1.0-rc.3' && '/home/srikanth/projects/Kublai/scripts/verify-release-artifacts.sh' checksum SHA256SUMS` | PASS | 0 | `artifacts/release-provenance/v0.1.0-rc.3/verify-checksums.log` |
| verify kublai-api-linux-x64.tar.gz signature | `cd '/home/srikanth/projects/Kublai/artifacts/release-provenance/v0.1.0-rc.3' && '/home/srikanth/projects/Kublai/scripts/verify-release-artifacts.sh' blob 'kublai-api-linux-x64.tar.gz' 'kublai-api-linux-x64.tar.gz.sig' 'kublai-api-linux-x64.tar.gz.crt'` | PASS | 0 | `artifacts/release-provenance/v0.1.0-rc.3/verify-kublai-api-linux-x64-tar-gz-signature.log` |
| verify kublai-worker-linux-x64.tar.gz signature | `cd '/home/srikanth/projects/Kublai/artifacts/release-provenance/v0.1.0-rc.3' && '/home/srikanth/projects/Kublai/scripts/verify-release-artifacts.sh' blob 'kublai-worker-linux-x64.tar.gz' 'kublai-worker-linux-x64.tar.gz.sig' 'kublai-worker-linux-x64.tar.gz.crt'` | PASS | 0 | `artifacts/release-provenance/v0.1.0-rc.3/verify-kublai-worker-linux-x64-tar-gz-signature.log` |
| verify kublai-api.sbom.cdx.json signature | `cd '/home/srikanth/projects/Kublai/artifacts/release-provenance/v0.1.0-rc.3' && '/home/srikanth/projects/Kublai/scripts/verify-release-artifacts.sh' blob 'kublai-api.sbom.cdx.json' 'kublai-api.sbom.cdx.json.sig' 'kublai-api.sbom.cdx.json.crt'` | PASS | 1 | `artifacts/release-provenance/v0.1.0-rc.3/verify-kublai-api-sbom-cdx-json-signature.log` |
| verify kublai-worker.sbom.cdx.json signature | `cd '/home/srikanth/projects/Kublai/artifacts/release-provenance/v0.1.0-rc.3' && '/home/srikanth/projects/Kublai/scripts/verify-release-artifacts.sh' blob 'kublai-worker.sbom.cdx.json' 'kublai-worker.sbom.cdx.json.sig' 'kublai-worker.sbom.cdx.json.crt'` | PASS | 0 | `artifacts/release-provenance/v0.1.0-rc.3/verify-kublai-worker-sbom-cdx-json-signature.log` |
| verify kublai-api-image.sbom.cdx.json signature | `cd '/home/srikanth/projects/Kublai/artifacts/release-provenance/v0.1.0-rc.3' && '/home/srikanth/projects/Kublai/scripts/verify-release-artifacts.sh' blob 'kublai-api-image.sbom.cdx.json' 'kublai-api-image.sbom.cdx.json.sig' 'kublai-api-image.sbom.cdx.json.crt'` | PASS | 0 | `artifacts/release-provenance/v0.1.0-rc.3/verify-kublai-api-image-sbom-cdx-json-signature.log` |
| verify kublai-worker-image.sbom.cdx.json signature | `cd '/home/srikanth/projects/Kublai/artifacts/release-provenance/v0.1.0-rc.3' && '/home/srikanth/projects/Kublai/scripts/verify-release-artifacts.sh' blob 'kublai-worker-image.sbom.cdx.json' 'kublai-worker-image.sbom.cdx.json.sig' 'kublai-worker-image.sbom.cdx.json.crt'` | PASS | 0 | `artifacts/release-provenance/v0.1.0-rc.3/verify-kublai-worker-image-sbom-cdx-json-signature.log` |
| verify kublai-helm-chart.sbom.cdx.json signature | `cd '/home/srikanth/projects/Kublai/artifacts/release-provenance/v0.1.0-rc.3' && '/home/srikanth/projects/Kublai/scripts/verify-release-artifacts.sh' blob 'kublai-helm-chart.sbom.cdx.json' 'kublai-helm-chart.sbom.cdx.json.sig' 'kublai-helm-chart.sbom.cdx.json.crt'` | PASS | 1 | `artifacts/release-provenance/v0.1.0-rc.3/verify-kublai-helm-chart-sbom-cdx-json-signature.log` |
| verify kublai-0.1.0-rc.3.tgz signature | `cd '/home/srikanth/projects/Kublai/artifacts/release-provenance/v0.1.0-rc.3' && '/home/srikanth/projects/Kublai/scripts/verify-release-artifacts.sh' blob 'kublai-0.1.0-rc.3.tgz' 'kublai-0.1.0-rc.3.tgz.sig' 'kublai-0.1.0-rc.3.tgz.crt'` | PASS | 0 | `artifacts/release-provenance/v0.1.0-rc.3/verify-kublai-0-1-0-rc-3-tgz-signature.log` |
| verify API image signature | `cd '/home/srikanth/projects/Kublai' && '/home/srikanth/projects/Kublai/scripts/verify-release-artifacts.sh' image 'ghcr.io/sremani/kublai-api@sha256:3b02e3f3675527edce065031c8104425188e254cbf60d27392f00dfc75b52460'` | PASS | 1 | `artifacts/release-provenance/v0.1.0-rc.3/verify-API-image-signature.log` |
| verify worker image signature | `cd '/home/srikanth/projects/Kublai' && '/home/srikanth/projects/Kublai/scripts/verify-release-artifacts.sh' image 'ghcr.io/sremani/kublai-worker@sha256:4dd99300a1cefae123e7d5bcd415088df386b4b8391bd58247ac9263cdaff904'` | PASS | 1 | `artifacts/release-provenance/v0.1.0-rc.3/verify-worker-image-signature.log` |

## Required Release Assets

- `kublai-api-linux-x64.tar.gz`
- `kublai-api-linux-x64.tar.gz.sig`
- `kublai-api-linux-x64.tar.gz.crt`
- `kublai-worker-linux-x64.tar.gz`
- `kublai-worker-linux-x64.tar.gz.sig`
- `kublai-worker-linux-x64.tar.gz.crt`
- `kublai-api.sbom.cdx.json`
- `kublai-api.sbom.cdx.json.sig`
- `kublai-api.sbom.cdx.json.crt`
- `kublai-worker.sbom.cdx.json`
- `kublai-worker.sbom.cdx.json.sig`
- `kublai-worker.sbom.cdx.json.crt`
- `kublai-api-image.sbom.cdx.json`
- `kublai-api-image.sbom.cdx.json.sig`
- `kublai-api-image.sbom.cdx.json.crt`
- `kublai-worker-image.sbom.cdx.json`
- `kublai-worker-image.sbom.cdx.json.sig`
- `kublai-worker-image.sbom.cdx.json.crt`
- `kublai-helm-chart.sbom.cdx.json`
- `kublai-helm-chart.sbom.cdx.json.sig`
- `kublai-helm-chart.sbom.cdx.json.crt`
- `kublai-0.1.0-rc.3.tgz`
- `kublai-0.1.0-rc.3.tgz.sig`
- `kublai-0.1.0-rc.3.tgz.crt`
- `OCI-IMAGES.txt`
- `SHA256SUMS`
