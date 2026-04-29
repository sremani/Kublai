module EnterpriseGaTicketArtifactTests

open System
open System.IO
open Xunit

let private repoRoot =
    let rec findRoot (dir: DirectoryInfo) =
        let hasReadme = File.Exists(Path.Combine(dir.FullName, "README.md"))
        let hasBoard = File.Exists(Path.Combine(dir.FullName, "docs", "58-enterprise-ga-ticket-board.md"))

        if hasReadme && hasBoard then
            dir.FullName
        elif isNull dir.Parent then
            failwithf "Could not locate repository root from %s" Environment.CurrentDirectory
        else
            findRoot dir.Parent

    findRoot (DirectoryInfo(Environment.CurrentDirectory))

let private readText relativePath =
    File.ReadAllText(Path.Combine(repoRoot, relativePath))

let private assertContains (expected: string) (actual: string) =
    Assert.Contains(expected, actual)

let private legacyBrandTokens =
    [ "Arti" + "fortress"
      "arti" + "fortress"
      "ARTI" + "FORTRESS" ]

let private isSkippedBrandScanPath (relativePath: string) =
    relativePath.StartsWith(".git/", StringComparison.Ordinal)
    || relativePath.StartsWith("artifacts/", StringComparison.Ordinal)
    || relativePath.EndsWith(".nettrace", StringComparison.Ordinal)
    || relativePath.Contains("/bin/", StringComparison.Ordinal)
    || relativePath.Contains("/obj/", StringComparison.Ordinal)

[<Fact>]
let ``enterprise GA board tracks tranche validation tickets`` () =
    let board = readText "docs/58-enterprise-ga-ticket-board.md"

    assertContains "| EGA-21T | Validate cloud-specific production examples | P1 | Validation | done |" board
    assertContains "| EGA-22T | Validate air-gapped/offline install plan | P1 | Validation | done |" board
    assertContains "| EGA-23T | Add release-artifact drill validation evidence | P1 | Validation | in_progress |" board
    assertContains "| EGA-25T | Validate package-format compatibility strategy | P1 | Validation | done |" board
    assertContains "| EGA-34T | Validate Kublai rebrand coverage | P0 | Validation | done |" board

[<Fact>]
let ``source-controlled tree has completed Kublai rebrand`` () =
    let policy = readText "docs/82-kublai-branding-and-rename-policy.md"
    let board = readText "docs/58-enterprise-ga-ticket-board.md"

    assertContains "Kublai is the product, codebase, documentation, deployment, and release brand." policy
    assertContains "docs/82-kublai-branding-and-rename-policy.md" board

    let allFiles =
        Directory.EnumerateFiles(repoRoot, "*", SearchOption.AllDirectories)
        |> Seq.choose (fun path ->
            let relativePath = Path.GetRelativePath(repoRoot, path).Replace('\\', '/')

            if isSkippedBrandScanPath relativePath then
                None
            else
                Some(relativePath, path))

    let offenders =
        [ for relativePath, path in allFiles do
              for token in legacyBrandTokens do
                  if relativePath.Contains(token, StringComparison.Ordinal) then
                      yield $"{relativePath} contains legacy brand token in path"

              let text =
                  try
                      Some(File.ReadAllText(path))
                  with _ ->
                      None

              match text with
              | Some content ->
                  for token in legacyBrandTokens do
                      if content.Contains(token, StringComparison.Ordinal) then
                          yield $"{relativePath} contains legacy brand token in content"
              | None -> () ]

    Assert.True(List.isEmpty offenders, String.concat Environment.NewLine offenders)

[<Fact>]
let ``LKE example values use external runtime secrets`` () =
    let preprod = readText "deploy/helm/kublai/values-lke-preprod.example.yaml"
    let prod = readText "deploy/helm/kublai/values-lke-production.example.yaml"
    let chartDefaults = readText "deploy/helm/kublai/values.yaml"
    let secretTemplate = readText "deploy/helm/kublai/templates/secret.yaml"

    assertContains "secrets:\n  create: true\n  existingSecretName: \"\"" chartDefaults
    assertContains "secrets:\n  create: false\n  existingSecretName: kublai-preprod-runtime" preprod
    assertContains "secrets:\n  create: false\n  existingSecretName: kublai-prod-runtime" prod
    assertContains "{{- if .Values.secrets.create }}" secretTemplate
    assertContains "{{ include \"kublai.secretName\" . }}" secretTemplate

[<Fact>]
let ``offline install plan has required bundle manifest and validation hook`` () =
    let plan = readText "docs/81-airgapped-offline-install-plan.md"
    let manifest = readText "deploy/offline/release-manifest.example.env"
    let makefile = readText "Makefile"

    for heading in
        [ "## Offline Bundle Contents"
          "## Mirror Procedure"
          "## Offline Verification"
          "## Offline Install Procedure"
          "## Offline Upgrade Procedure"
          "## Unsupported Assumptions" ] do
        assertContains heading plan

    for key in
        [ "KUBLAI_RELEASE_TAG="
          "KUBLAI_CHART_PACKAGE="
          "KUBLAI_API_IMAGE="
          "KUBLAI_WORKER_IMAGE="
          "KUBLAI_SHA256SUMS="
          "KUBLAI_HELM_SBOM="
          "KUBLAI_OFFLINE_REGISTRY=" ] do
        assertContains key manifest

    assertContains "offline-install-plan-validate:" makefile

[<Fact>]
let ``release artifact drill reports require release metadata`` () =
    let phase6Drill = readText "scripts/phase6-drill.sh"
    let upgradeDrill = readText "scripts/upgrade-compatibility-drill.sh"
    let validator = readText "scripts/release-artifact-drill-validate.sh"

    for script in [ phase6Drill; upgradeDrill ] do
        assertContains "KUBLAI_RELEASE_TAG" script
        assertContains "KUBLAI_API_IMAGE_DIGEST" script
        assertContains "KUBLAI_WORKER_IMAGE_DIGEST" script
        assertContains "KUBLAI_HELM_CHART_DIGEST" script
        assertContains "KUBLAI_RELEASE_SBOM_PATH" script
        assertContains "KUBLAI_RELEASE_PROVENANCE_REPORT" script

    assertContains "release tag" validator
    assertContains "API image digest" validator
    assertContains "worker image digest" validator
    assertContains "Helm chart digest" validator
    assertContains "is unset" validator

[<Fact>]
let ``package format strategy keeps GA claims inside supported API boundary`` () =
    let strategy = readText "docs/80-package-format-compatibility-strategy.md"
    let envelope = readText "docs/59-enterprise-product-envelope.md"

    assertContains "Kublai enterprise GA supports the Kublai HTTP API only." strategy
    assertContains "Day-one support does not include native package-manager protocols" strategy
    assertContains "| Generic blob repository | P1 follow-up |" strategy
    assertContains "| Test Class | Required Coverage |" strategy
    assertContains "No protocol track may enter the enterprise support envelope until its test" strategy
    assertContains "docs/80-package-format-compatibility-strategy.md" envelope

[<Fact>]
let ``Garage evaluation lane is tracked and runnable`` () =
    let board = readText "docs/58-enterprise-ga-ticket-board.md"
    let exitPlan = readText "docs/74-object-storage-independence-and-minio-exit-plan.md"
    let evaluation = readText "docs/83-garage-minio-replacement-evaluation.md"
    let makefile = readText "Makefile"
    let compose = readText "docker-compose.garage.yml"
    let config = readText "deploy/garage/garage.toml"
    let validator = readText "scripts/garage-compatibility-validate.sh"
    let workflow = readText ".github/workflows/garage-compatibility.yml"
    let objectStorageTests = readText "tests/Kublai.Domain.Tests/ObjectStorageTests.fs"
    let report = readText "docs/reports/garage-compatibility-latest.md"
    let kindHaValidator = readText "scripts/kind-ha-validate.sh"
    let helmCertifier = readText "scripts/helm-certify.sh"
    let garageKindDependency = readText "deploy/kind/dependencies-garage.yaml"
    let garageHelmValues = readText "deploy/helm/kublai/values-kind-garage.yaml"
    let haKubernetesReport = readText "docs/reports/ha-kubernetes-validation-latest.md"
    let helmCertificationReport = readText "docs/reports/helm-certification-latest.md"
    let garageDecision = readText "docs/84-garage-operations-licensing-and-migration-decision.md"

    assertContains "| EGA-35 | Evaluate Garage as MinIO replacement candidate | P0 | Storage/Launch Risk | done |" board
    assertContains "| EGA-35T | Validate Garage compatibility evaluation lane | P0 | Validation | done |" board
    assertContains "| EGA-36 | Expand Garage provider contract tests | P0 | Storage/Validation | done |" board
    assertContains "| EGA-36T | Validate Garage provider contract tests in CI | P0 | Validation | done |" board
    assertContains "| EGA-37 | Add Garage-backed CI compatibility lane | P0 | Storage/CI | done |" board
    assertContains "| EGA-37T | Validate Garage CI evidence and report publication | P0 | Validation | done |" board
    assertContains "| EGA-38 | Add Garage option for kind and Helm validation dependencies | P1 | Deployment | done |" board
    assertContains "| EGA-38T | Validate Garage kind and Helm dependency option | P1 | Validation | done |" board
    assertContains "| EGA-39 | Document Garage operations, licensing, and migration decision | P1 | Storage/Ops | done |" board
    assertContains "| EGA-39T | Validate Garage go/no-go decision artifacts | P1 | Validation | done |" board
    assertContains "make garage-compatibility-validate" evaluation
    assertContains "Boorchu remains deferred unless Garage is rejected" evaluation
    assertContains "| EGA-36 | Expand provider contract tests for Garage, MinIO, and managed S3-compatible stores | EGA-35 |" evaluation
    assertContains "| EGA-39T | Validate Garage go/no-go artifacts before closing EGA-35 | EGA-39 |" evaluation
    assertContains "Run `EGA-36` and `EGA-36T` first" evaluation
    assertContains ".github/workflows/garage-compatibility.yml" evaluation
    assertContains "KIND_OBJECT_STORAGE_PROVIDER=garage make kind-ha-validate" evaluation
    assertContains "HELM_CERT_OBJECT_STORAGE_PROVIDER=garage make helm-certify" evaluation
    assertContains "`external`" evaluation
    assertContains "docs/84-garage-operations-licensing-and-migration-decision.md" evaluation
    assertContains "Boorchu remains deferred unless Garage is rejected" evaluation
    assertContains "make garage-compatibility-validate" exitPlan
    assertContains ".github/workflows/garage-compatibility.yml" exitPlan
    assertContains "KIND_OBJECT_STORAGE_PROVIDER=garage make kind-ha-validate" exitPlan
    assertContains "HELM_CERT_OBJECT_STORAGE_PROVIDER=garage make helm-certify" exitPlan
    assertContains "docs/84-garage-operations-licensing-and-migration-decision.md" exitPlan
    assertContains "`Boorchu` remains deferred unless the Garage decision record is superseded" exitPlan
    assertContains "garage-compatibility-validate:" makefile
    assertContains "dxflrs/garage:v2.3.0" compose
    assertContains "s3_region = \"us-east-1\"" config
    assertContains "Object storage provider contract check availability succeeds" objectStorageTests
    assertContains "Object storage provider contract supports multipart upload full download and metadata" objectStorageTests
    assertContains "Object storage provider contract supports ranged download" objectStorageTests
    assertContains "Object storage provider contract maps missing objects to not found" objectStorageTests
    assertContains "Object storage provider contract maps unsatisfiable ranges" objectStorageTests
    assertContains "Object storage provider contract deletes objects" objectStorageTests
    assertContains "Object storage provider contract aborts incomplete multipart uploads" objectStorageTests
    assertContains "Object storage client supports multipart upload and ranged download" validator
    assertContains "Provider availability check" validator
    assertContains "Missing-object NotFound mapping" validator
    assertContains "Invalid-range mapping" validator
    assertContains "Incomplete multipart upload abort semantics" validator
    assertContains "docs/reports/garage-compatibility-latest.md" validator
    assertContains "name: garage-compatibility" workflow
    assertContains "make garage-compatibility-validate" workflow
    assertContains "docs/reports/garage-compatibility-latest.md" workflow
    assertContains "GITHUB_STEP_SUMMARY" workflow
    assertContains "actions/upload-artifact" workflow
    assertContains "garage-compatibility-report" workflow
    assertContains "src/Kublai.Api/ObjectStorage.fs" workflow
    assertContains "scripts/garage-compatibility-validate.sh" workflow
    assertContains "docs/83-garage-minio-replacement-evaluation.md" workflow
    assertContains "- Result: PASS" report
    assertContains "Provider availability check" report
    assertContains "Missing-object NotFound mapping" report
    assertContains "Invalid-range mapping" report
    assertContains "Incomplete multipart upload abort semantics" report
    assertContains "object_storage_provider=\"${KIND_OBJECT_STORAGE_PROVIDER:-minio}\"" kindHaValidator
    assertContains "garage)" kindHaValidator
    assertContains "external)" kindHaValidator
    assertContains "deploy/kind/dependencies-garage.yaml" kindHaValidator
    assertContains "--values \"$storage_values\"" kindHaValidator
    assertContains "ObjectStorage__Endpoint=\"$object_storage_endpoint\"" kindHaValidator
    assertContains "object_storage_provider=\"${HELM_CERT_OBJECT_STORAGE_PROVIDER:-minio}\"" helmCertifier
    assertContains "garage)" helmCertifier
    assertContains "external)" helmCertifier
    assertContains "deploy/kind/dependencies-garage.yaml" helmCertifier
    assertContains "deploy/helm/kublai/values-kind-garage.yaml" evaluation
    assertContains "--values \"$storage_values\"" helmCertifier
    assertContains "ObjectStorage__Endpoint=\"$object_storage_endpoint\"" helmCertifier
    assertContains "name: garage" garageKindDependency
    assertContains "image: dxflrs/garage:v2.3.0" garageKindDependency
    assertContains "rpc_public_addr = \"garage:3901\"" garageKindDependency
    assertContains "s3_region = \"us-east-1\"" garageKindDependency
    assertContains "ObjectStorage__Endpoint: http://garage:3900" garageHelmValues
    assertContains "generated-by-garage-bootstrap" garageHelmValues
    assertContains "- object storage provider: garage" haKubernetesReport
    assertContains "- object storage endpoint: http://garage:3900" haKubernetesReport
    assertContains "- selected object-storage dependency startup: garage" haKubernetesReport
    assertContains "- object storage provider: garage" helmCertificationReport
    assertContains "- object storage endpoint: http://garage:3900" helmCertificationReport
    assertContains "- selected object-storage dependency startup: garage" helmCertificationReport
    assertContains "# Garage Operations, Licensing, And Migration Decision" garageDecision
    assertContains "## Decision" garageDecision
    assertContains "## Release And Licensing Decision" garageDecision
    assertContains "AGPLv3" garageDecision
    assertContains "## Day-0 Workflow" garageDecision
    assertContains "## Day-1 Workflow" garageDecision
    assertContains "## Day-2 Workflow" garageDecision
    assertContains "## Backup And Restore" garageDecision
    assertContains "## MinIO-To-Garage Migration" garageDecision
    assertContains "## Go/No-Go" garageDecision
    assertContains "Boorchu remains deferred" garageDecision
    assertContains "Garage repository states that Garage is released under AGPLv3" garageDecision
    assertContains "https://garagehq.deuxfleurs.fr/documentation/reference-manual/monitoring/" garageDecision
    assertContains "https://garagehq.deuxfleurs.fr/documentation/reference-manual/s3-compatibility/" garageDecision
