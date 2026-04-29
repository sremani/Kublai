# Garage Operations, Licensing, And Migration Decision

Last updated: 2026-04-29

## Decision

Adopt Garage as the maintained self-hosted S3-compatible replacement candidate
for Kublai validation and self-hosted reference deployments.

Production for `kublai.com` should still use managed S3-compatible object
storage until a customer explicitly requires self-hosting. Garage is now
accepted for local, kind, Helm, and CI validation paths.

Boorchu remains deferred. It must not start as a replacement project unless a
future decision record rejects Garage or identifies a launch-critical
exception.

## Decision Basis

Garage has passed the Kublai object-storage contract used today:

- provider availability
- bucket bootstrap
- SigV4 authentication through the AWS SDK
- multipart upload start, presigned part upload, complete, and abort
- full object download
- ranged object download
- object metadata and ETag behavior
- delete semantics
- missing-object `NotFound` mapping
- invalid-range mapping

Evidence:

- `docs/reports/garage-compatibility-latest.md`
- `docs/reports/ha-kubernetes-validation-latest.md`
- `docs/reports/helm-certification-latest.md`
- `.github/workflows/garage-compatibility.yml`

Garage is not accepted as a full S3 clone. Kublai only accepts it for the S3
subset Kublai uses. Unsupported or non-goal features remain outside the Kublai
enterprise support envelope unless separately certified.

## Source Review

Sources checked on 2026-04-29:

- Garage website and documentation: `https://garagehq.deuxfleurs.fr/`
- Garage configuration reference:
  `https://garagehq.deuxfleurs.fr/documentation/reference-manual/configuration/`
- Garage durability and repair guide:
  `https://garagehq.deuxfleurs.fr/documentation/operations/durability-repairs/`
- Garage failure recovery guide:
  `https://garagehq.deuxfleurs.fr/documentation/operations/recovering/`
- Garage monitoring reference:
  `https://garagehq.deuxfleurs.fr/documentation/reference-manual/monitoring/`
- Garage S3 compatibility reference:
  `https://garagehq.deuxfleurs.fr/documentation/reference-manual/s3-compatibility/`
- Garage repository mirror:
  `https://github.com/deuxfleurs-org/garage`

Relevant source-derived constraints:

- Garage implements S3-compatible APIs, including the core object and multipart
  operations Kublai uses.
- Garage's recommended durable posture is multi-node, multi-zone, with
  replication factor 3 where possible.
- Replication factor 1 has no redundancy and is suitable only for tests or
  disposable local validation.
- Garage stores metadata separately from object data. Metadata contains cluster
  identity, network configuration, buckets, keys, object indexes, object
  versions, and block indexes.
- Garage supports metadata snapshots and repair commands, but snapshot and
  repair workflows are operational procedures, not a substitute for tested
  backups.
- Garage exports Prometheus-style metrics for version, disk availability,
  cluster health, API request/error rates, block manager state, and internal
  RPC behavior.
- Garage's public S3 compatibility table marks several advanced S3 features as
  missing, including bucket versioning, S3 replication APIs, object lock/legal
  hold APIs, server-side bucket encryption APIs, notification APIs, and tagging
  APIs.
- The Garage repository states that Garage is released under AGPLv3.

## Supported Kublai Use

Supported now:

- local Garage compatibility evaluation through `make garage-compatibility-validate`
- GitHub Actions Garage compatibility evidence through
  `.github/workflows/garage-compatibility.yml`
- kind HA validation with
  `KIND_OBJECT_STORAGE_PROVIDER=garage make kind-ha-validate`
- Helm certification with
  `HELM_CERT_OBJECT_STORAGE_PROVIDER=garage make helm-certify`
- managed S3-compatible providers through `*_OBJECT_STORAGE_PROVIDER=external`

Not supported yet:

- bundled Garage binaries inside Kublai release archives
- offline redistribution of Garage container images as part of a Kublai bundle
- customer production self-hosted Garage support without a site-specific storage
  topology, backup plan, monitoring plan, and restore drill
- Kublai features that require unsupported Garage S3 features such as object
  lock, bucket versioning, S3 replication APIs, server-side bucket encryption
  APIs, notification APIs, or tagging APIs

## Release And Licensing Decision

Garage may be referenced by Kublai deployment artifacts as an optional
third-party dependency. Kublai may include source-controlled manifests,
configuration examples, and validation scripts that pull or run an upstream
Garage image.

Kublai must not vendor, modify, or redistribute Garage binaries or container
images in Kublai release bundles until release/legal review approves the exact
distribution path. If a release bundle later includes Garage artifacts, the
release owner must verify license notices, source availability, image provenance,
and any AGPLv3 network-use obligations before publication.

Kublai application code remains independently licensed and communicates with
Garage only through the S3-compatible HTTP boundary. Any Kublai-owned patches to
Garage, Garage sidecars, or Garage-derived components require a separate legal
review before they can ship.

Procurement language:

- Garage is an optional self-hosted object-storage dependency.
- Managed S3-compatible storage remains the preferred hosted production option.
- The AGPLv3 license must be disclosed in procurement and release evidence if
  Garage is part of a proposed self-hosted deployment.

## Day-0 Workflow

Day-0 is initial setup before any Kublai workload depends on Garage.

1. Choose provider mode.
   - `minio` remains the temporary local default.
   - `garage` selects in-cluster Garage for validation.
   - `external` selects managed S3-compatible storage.
2. For production-like Garage, reject single-node `replication_factor = 1`.
   Require at least three storage nodes across failure zones for the default
   durable profile.
3. Allocate separate persistent storage for metadata and object data.
   Metadata should use fast, reliable storage; object data can use capacity
   storage sized to the declared Garage layout capacity.
4. Configure TLS through ingress or a reverse proxy for S3 traffic.
   Do not expose raw unauthenticated admin or metrics endpoints.
5. Generate unique RPC, admin, metrics, and S3 credentials per environment.
   Do not reuse the local validation secrets in production.
6. Create bucket and key material using Garage bootstrap commands.
7. Run the Kublai provider contract suite before any cutover:
   `make garage-compatibility-validate` for local evidence, or the equivalent
   environment-backed object-storage integration tests for managed/self-hosted
   endpoints.

## Day-1 Workflow

Day-1 is normal service operation.

- Monitor Garage cluster health, connected storage nodes, available partitions,
  disk availability, S3 request/error counters, block resync queues, and RPC
  timeout/error counters.
- Alert on:
  - cluster unavailable
  - lost quorum for any partition
  - persistent disconnected storage nodes
  - metadata or data disk nearing capacity
  - nonzero block resync errors that do not clear quickly
  - S3 5xx error rate or latency regression
  - failed metadata snapshots
- Keep metadata snapshots enabled and copied off-node.
- Keep Garage admin and metrics tokens in the same secret-management class as
  database and object-storage credentials.
- Rotate Kublai S3 access keys by creating a new Garage key, granting bucket
  access, updating Kublai runtime secrets, restarting Kublai workloads, running
  smoke tests, and then revoking the old key.
- Treat `garage layout show` and `garage status` as required preflight checks
  before topology changes.

## Day-2 Workflow

Day-2 is maintenance, recovery, and change management.

- Upgrades:
  - read Garage release notes before changing image tags
  - snapshot metadata before upgrade
  - upgrade one node or failure zone at a time where topology allows
  - run Kublai object-storage contract tests after upgrade
- Repairs:
  - use Garage repair commands only with an explicit incident ticket
  - run disk-intensive scrub/repair work outside peak traffic windows
  - record the command, target nodes, start time, and observed queue/error
    metrics
- Disk replacement:
  - if only object data is lost and metadata survives, replace the disk and run
    block repair/resync
  - if metadata is lost, follow the Garage replacement-node or metadata-snapshot
    recovery procedure
- Topology changes:
  - use `garage layout show` before applying any layout change
  - apply layout changes through versioned `garage layout apply`
  - run repair and contract validation after the layout stabilizes

## Backup And Restore

Minimum backup set:

- Garage metadata snapshots
- Garage configuration files
- RPC/admin/metrics/S3 credentials from the secret manager
- object data volumes or storage-system snapshots where the topology requires
  recovery faster than cluster re-replication can provide
- Kublai database backups, because Kublai metadata in Postgres must stay
  consistent with object storage contents

Backup procedure:

1. Trigger or verify a recent Garage metadata snapshot.
2. Snapshot or back up `metadata_dir`, `metadata_snapshots_dir`, and Garage
   configuration.
3. Back up object data volumes when using single-node or small-cluster
   self-hosted topologies.
4. Store backup manifests with Garage version, Kublai version, bucket names,
   key IDs, layout status, and timestamps.
5. Run a restore drill before accepting Garage for a production tenant.

Restore procedure:

1. Stop Kublai writes or isolate the affected tenant.
2. Restore Kublai Postgres state to the selected recovery point.
3. Restore Garage metadata from a verified snapshot or recover metadata from
   healthy peer nodes when supported by the topology.
4. Restore object data volumes when required by the topology.
5. Start Garage and verify `garage status`, cluster layout, bucket list, and key
   access.
6. Run Kublai object-storage contract tests against the restored endpoint.
7. Run Kublai API smoke and production preflight before reopening writes.

Rollback:

- If Garage migration fails before write cutover, keep Kublai pointed at the
  old S3-compatible endpoint and discard the Garage copy.
- If failure occurs after write cutover, freeze writes, compare Postgres package
  metadata against object digests in both stores, and choose the endpoint with
  complete digest coverage before reopening traffic.

## MinIO-To-Garage Migration

The safe migration path is copy-and-verify, not in-place mutation.

1. Freeze writes or enter a maintenance window.
2. Record source MinIO endpoint, bucket, access key ID, and object count.
3. Bootstrap Garage bucket and access key.
4. Copy objects from MinIO to Garage using an S3-compatible tool such as
   `rclone`, `aws s3 sync`, or a purpose-built migration job.
5. Verify object counts and byte totals.
6. Sample or full-verify Kublai package blob digests against Garage.
7. Point Kublai runtime configuration at Garage:
   - `ObjectStorage__Endpoint`
   - `ObjectStorage__Bucket`
   - `ObjectStorage__AccessKey`
   - `ObjectStorage__SecretKey`
8. Restart Kublai API and worker workloads.
9. Run production preflight, object-storage contract tests, and publish/download
   smoke tests.
10. Keep MinIO read-only until rollback risk is accepted.

Unsupported assumptions:

- Do not assume Garage supports every MinIO feature.
- Do not migrate object-lock, legal-hold, bucket-versioning, notification,
  tagging, or server-side bucket-encryption workflows without separate
  compatibility tickets.
- Do not use the single-node validation manifest for production durability.

## Go/No-Go

Decision: Go for Garage as Kublai's maintained self-hosted validation and
reference-deployment dependency.

Production decision: managed S3-compatible storage remains preferred for
`kublai.com`.

Boorchu decision: deferred. Do not create the Boorchu repository unless Garage
later fails one of these explicit gates:

- Kublai's current object-storage provider contract stops passing
- Garage licensing becomes unacceptable for supported self-hosted deployments
- Garage operations cannot meet a customer recovery objective after restore
  drills
- Kublai needs an S3 feature Garage does not support and cannot reasonably
  avoid, such as object lock or bucket versioning

## Open Follow-Ups

- Add a production-grade Garage Helm chart or document the supported upstream
  chart if one is chosen.
- Add a restore-drill script for Garage metadata and data volumes before any
  customer production self-hosted deployment.
- Add managed-provider certification evidence for the `kublai.com` production
  provider once that provider is selected.
