# Object Storage Independence And MinIO Exit Plan

Last updated: 2026-04-29

## Purpose

This document tracks the Kublai plan to remove MinIO as a strategic
dependency after the upstream open-source repository was archived and made
read-only.

Kublai should continue to support S3-compatible object storage as an
interface, but the project should not depend on unmaintained MinIO community
artifacts as the default validation or self-hosted production path.

## Current Risk

The repository currently uses MinIO in local and kind validation paths:

- Docker Compose development stack
- kind Kubernetes dependency stack
- Helm certification
- HA Kubernetes validation
- local storage bootstrap scripts

Production guidance already permits managed S3-compatible object storage such
as cloud object storage. That remains the preferred near-term path for
`kublai.com`.

Risk posture:

- using managed S3-compatible storage for production is acceptable
- using MinIO as a local test fixture is acceptable only as a temporary bridge
- presenting MinIO as the recommended self-hosted object-store dependency is no
  longer acceptable for enterprise GA

## Near-Term Deployment Decision

For `kublai.com`, do not self-host object storage.

Use a managed S3-compatible provider:

- DigitalOcean Spaces for a DigitalOcean launch
- AWS S3 if the production region/provider moves to AWS
- Cloudflare R2 if egress cost and Cloudflare integration dominate

The Kublai deployment must validate against the selected managed object
store before production cutover.

## Replacement Candidate Decision

Before creating a Kublai-owned object-store project, evaluate Garage as the
preferred maintained self-hosted replacement candidate.

Garage is attractive because it is already a Rust, S3-compatible,
self-hostable object store designed for small-to-medium distributed
deployments. It should be treated as a candidate dependency, not assumed safe
until Kublai's exact object-storage contract passes against it.

If Garage passes compatibility, operations, and licensing review, prefer Garage
over building a new object store.

Garage has now passed the Kublai validation, operations, migration, and
licensing review gates for validation and self-hosted reference deployments.
The final decision record is
`docs/84-garage-operations-licensing-and-migration-decision.md`.

If Garage fails on a launch-critical requirement, create a separate side
project for a Kublai-owned object store:

- working name: `Boorchu`
- purpose: small, boring, S3-compatible object storage for Kublai
  deployments and tests
- license: choose deliberately before coding
- implementation language: TBD
- first target: single-node durable object storage with the exact S3 subset
  Kublai needs

This should be a separate repository, not a subdirectory in Kublai, so the
object store can evolve with its own release cadence, security policy, and
compatibility test suite.

## Minimum S3 Compatibility Surface

Kublai currently needs:

- bucket existence and creation for local/dev paths
- object put/get/delete
- multipart upload create, upload part, complete, and abort
- range reads
- object metadata needed for digest/length validation
- deterministic error behavior for missing objects and failed uploads

Nice-to-have later:

- bucket lifecycle policies
- object versioning
- server-side encryption hooks
- retention/legal-hold integration
- replication
- admin API and web console

Do not start with a full S3 clone. Start with the subset Kublai actually
uses and prove it with contract tests.

## Migration Plan

Phase 1: dependency boundary

- Add an object-storage compatibility matrix.
- Keep MinIO only as a temporary test fixture.
- Add a managed-object-store certification path for `kublai.com`.
- Ensure Kublai docs say "S3-compatible object storage" rather than
  recommending MinIO.

Phase 2: replacement evaluation

- Compare managed providers: DigitalOcean Spaces, AWS S3, Cloudflare R2.
- Evaluate Garage as the primary self-hosted replacement candidate.
- Compare any other maintained self-hosted alternatives only if Garage fails
  Kublai's compatibility or operations gates.
- Decide whether `Boorchu` is worth building before first production customer
  or should remain a follow-up.

Phase 3: side-project bootstrap

- Create the `Boorchu` repository only if the Garage evaluation fails or leaves
  unacceptable launch risk.
- Define the S3 subset contract.
- Build an Kublai object-storage conformance test suite.
- Implement single-node local mode.
- Add Docker image and Helm/Compose examples.

Phase 4: production hardening

- Add durability model, fsync/write-ahead semantics, and corruption detection.
- Add backup/restore workflow.
- Add metrics and health checks.
- Add security review and release provenance.

## Kublai Changes Needed

- Remove MinIO language from customer-facing production recommendations.
- Keep `deploy/kind/dependencies.yaml` explicitly marked as temporary local
  validation infrastructure.
- Add provider-specific object-storage examples for the selected production
  provider.
- Add contract tests that can run against MinIO, managed S3-compatible storage,
  Garage, and future `Boorchu` if needed.
- Use `make garage-compatibility-validate` as the first Garage contract test
  lane while MinIO remains the default local fixture.
- Run `.github/workflows/garage-compatibility.yml` as the separate Garage CI
  evidence lane for object-storage and Garage evaluation changes.
- Allow kind HA and Helm certification to select `minio`, `garage`, or
  `external` S3-compatible object storage while keeping MinIO as the temporary
  default.
- Add a release gate requiring object-storage provider certification for
  `kublai.com`.
- Use `docs/84-garage-operations-licensing-and-migration-decision.md` as the
  Garage go/no-go decision record and Boorchu deferral gate.

## Acceptance Criteria

- A ticket exists on the enterprise GA board.
- Production hosting plan stops implying MinIO for production.
- Local validation docs identify MinIO as temporary.
- A Garage evaluation ticket exists with compatibility, licensing, operations,
  and migration acceptance criteria.
- The first Garage validation hook exists and runs the Kublai object-storage
  integration test against Garage.
- The Garage compatibility workflow publishes
  `docs/reports/garage-compatibility-latest.md` as CI summary and artifact
  evidence.
- `KIND_OBJECT_STORAGE_PROVIDER=garage make kind-ha-validate` and
  `HELM_CERT_OBJECT_STORAGE_PROVIDER=garage make helm-certify` are documented
  provider-selection paths.
- `docs/84-garage-operations-licensing-and-migration-decision.md` documents
  Garage operations, AGPLv3 release posture, backup/restore, MinIO migration,
  rollback, and the final go/no-go decision.
- `Boorchu` remains deferred unless the Garage decision record is superseded by
  an explicit Garage rejection or exception.
- Kublai has an object-storage compatibility test plan.
- `kublai.com` production cutover uses managed object storage until a
  supported replacement is validated.

## References

- Upstream repository state: `https://github.com/minio/minio/issues/21714`
- Kublai hosting plan:
  `docs/73-kublai-com-production-hosting-plan.md`
- Kublai production cutover:
  `docs/72-installation-and-production-cutover-guide.md`
- Garage operations, licensing, migration, and final decision:
  `docs/84-garage-operations-licensing-and-migration-decision.md`
