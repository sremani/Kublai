module ObjectStorageTests

open System
open System.IO
open System.Net.Http
open System.Text
open System.Threading
open ObjectStorage
open Xunit
open Xunit.Sdk

let private readEnvOrDefault key defaultValue =
    match Environment.GetEnvironmentVariable(key) with
    | null
    | "" -> defaultValue
    | value -> value

let private buildClient () =
    let config =
        { Endpoint = readEnvOrDefault "ObjectStorage__Endpoint" "http://localhost:9000"
          AccessKey = readEnvOrDefault "ObjectStorage__AccessKey" "kublai"
          SecretKey = readEnvOrDefault "ObjectStorage__SecretKey" "kublai-secret"
          Bucket = readEnvOrDefault "ObjectStorage__Bucket" "kublai-dev"
          PresignPartTtlSeconds = 900 }

    createClient config

let private ensureObjectStorageAvailable (endpoint: string) =
    use client = new HttpClient()
    client.Timeout <- TimeSpan.FromSeconds(2.0)

    try
        // S3-compatible stores often return 403/404 at root without auth; any response proves reachability.
        use response = client.GetAsync(Uri(endpoint)).Result
        ignore response.StatusCode
    with ex ->
        raise (SkipException.ForSkip($"Skipping object storage test: S3-compatible store unavailable at {endpoint}. Details: {ex.Message}"))

let private requireOk result =
    match result with
    | Ok value -> value
    | Error err -> failwithf "Object storage operation failed: %A" err

let private requireError result =
    match result with
    | Ok value -> failwithf "Expected object storage operation to fail, but it succeeded with: %A" value
    | Error err -> err

let private toCompletedPartEtag (response: HttpResponseMessage) =
    let headerValue =
        if isNull response.Headers.ETag then
            match response.Headers.TryGetValues("ETag") with
            | true, values -> values |> Seq.tryHead |> Option.defaultValue ""
            | _ -> ""
        else
            response.Headers.ETag.Tag

    let normalized = headerValue.Trim().Trim('"')

    if String.IsNullOrWhiteSpace normalized then
        failwith "ETag header was missing from upload part response."
    else
        normalized

let private integrationContext () =
    let endpoint = readEnvOrDefault "ObjectStorage__Endpoint" "http://localhost:9000"
    ensureObjectStorageAvailable endpoint
    buildClient (), CancellationToken.None

let private uploadObject (client: IObjectStorageClient) (ct: CancellationToken) (objectKey: string) (payload: byte array) =
    let session = client.StartMultipartUpload(objectKey, ct).Result |> requireOk

    try
        let presignedPart =
            client.PresignUploadPart(session.ObjectKey, session.UploadId, 1, DateTimeOffset.UtcNow.AddMinutes(10.0))
            |> requireOk

        use httpClient = new HttpClient()
        use putContent = new ByteArrayContent(payload)
        use putResponse = httpClient.PutAsync(presignedPart.Url, putContent).Result

        Assert.True(
            putResponse.IsSuccessStatusCode,
            $"Expected successful part upload but received {(int putResponse.StatusCode)}."
        )

        let completedPartEtag = toCompletedPartEtag putResponse

        client.CompleteMultipartUpload(
            session.ObjectKey,
            session.UploadId,
            [ { PartNumber = 1; ETag = completedPartEtag } ],
            ct
        )
        |> fun task -> task.Result
        |> requireOk
        |> ignore

        session.ObjectKey
    with ex ->
        client.AbortMultipartUpload(session.ObjectKey, session.UploadId, ct).Result |> ignore
        raise ex

let private readAllBytes (downloaded: DownloadedObject) =
    use copy = new MemoryStream()
    downloaded.Stream.CopyTo(copy)
    downloaded.Dispose()
    copy.ToArray()

let private assertNotFound err =
    match err with
    | NotFound _ -> ()
    | other -> failwithf "Expected NotFound, got %A" other

let private assertInvalidRange err =
    match err with
    | InvalidRange _ -> ()
    | other -> failwithf "Expected InvalidRange, got %A" other

[<Fact>]
[<Trait("Category", "Integration")>]
let ``Object storage provider contract check availability succeeds`` () =
    let client, ct = integrationContext ()
    client.CheckAvailability(ct).Result |> requireOk |> ignore

[<Fact>]
[<Trait("Category", "Integration")>]
let ``Object storage provider contract supports multipart upload full download and metadata`` () =
    let client, ct = integrationContext ()
    let objectKey = $"provider-contract-metadata-{Guid.NewGuid():N}.bin"
    let payload = Encoding.UTF8.GetBytes("provider-contract-metadata-payload")

    let uploadedKey = uploadObject client ct objectKey payload
    let downloaded = client.DownloadObject(uploadedKey, None, ct).Result |> requireOk

    Assert.Equal<int64>(int64 payload.Length, downloaded.ContentLength)
    Assert.True(downloaded.ETag.IsSome, "Expected object storage provider to return an ETag.")
    Assert.Equal<byte>(payload, readAllBytes downloaded)

    client.DeleteObject(uploadedKey, ct).Result |> requireOk |> ignore

[<Fact>]
[<Trait("Category", "Integration")>]
let ``Object storage provider contract supports ranged download`` () =
    let client, ct = integrationContext ()
    let objectKey = $"provider-contract-range-{Guid.NewGuid():N}.bin"
    let payload = Encoding.UTF8.GetBytes("provider-contract-range-payload")

    let uploadedKey = uploadObject client ct objectKey payload
    let ranged = client.DownloadObject(uploadedKey, Some(3L, Some 8L), ct).Result |> requireOk

    Assert.Equal(Net.HttpStatusCode.PartialContent, ranged.StatusCode)
    Assert.True(ranged.ContentRange.IsSome, "Expected object storage provider to return Content-Range.")
    Assert.Equal<byte>(payload.[3..8], readAllBytes ranged)

    client.DeleteObject(uploadedKey, ct).Result |> requireOk |> ignore

[<Fact>]
[<Trait("Category", "Integration")>]
let ``Object storage provider contract maps missing objects to not found`` () =
    let client, ct = integrationContext ()
    let objectKey = $"provider-contract-missing-{Guid.NewGuid():N}.bin"

    client.DownloadObject(objectKey, None, ct).Result |> requireError |> assertNotFound

[<Fact>]
[<Trait("Category", "Integration")>]
let ``Object storage provider contract maps unsatisfiable ranges`` () =
    let client, ct = integrationContext ()
    let objectKey = $"provider-contract-invalid-range-{Guid.NewGuid():N}.bin"
    let payload = Encoding.UTF8.GetBytes("range")

    let uploadedKey = uploadObject client ct objectKey payload

    client.DownloadObject(uploadedKey, Some(100L, Some 110L), ct).Result
    |> requireError
    |> assertInvalidRange

    client.DeleteObject(uploadedKey, ct).Result |> requireOk |> ignore

[<Fact>]
[<Trait("Category", "Integration")>]
let ``Object storage provider contract deletes objects`` () =
    let client, ct = integrationContext ()
    let objectKey = $"provider-contract-delete-{Guid.NewGuid():N}.bin"
    let payload = Encoding.UTF8.GetBytes("provider-contract-delete-payload")

    let uploadedKey = uploadObject client ct objectKey payload
    client.DeleteObject(uploadedKey, ct).Result |> requireOk |> ignore

    client.DownloadObject(uploadedKey, None, ct).Result |> requireError |> assertNotFound

[<Fact>]
[<Trait("Category", "Integration")>]
let ``Object storage provider contract aborts incomplete multipart uploads`` () =
    let client, ct = integrationContext ()
    let objectKey = $"provider-contract-abort-{Guid.NewGuid():N}.bin"
    let session = client.StartMultipartUpload(objectKey, ct).Result |> requireOk

    client.AbortMultipartUpload(session.ObjectKey, session.UploadId, ct).Result |> requireOk |> ignore

    client.CompleteMultipartUpload(
        session.ObjectKey,
        session.UploadId,
        [ { PartNumber = 1; ETag = "aborted" } ],
        ct
    )
    |> fun task -> task.Result
    |> requireError
    |> assertNotFound

[<Fact>]
[<Trait("Category", "Integration")>]
let ``Object storage client supports multipart upload and ranged download`` () =
    let client, ct = integrationContext ()
    let objectKey = $"phase2-object-storage-test-{Guid.NewGuid():N}.bin"
    let payload = Encoding.UTF8.GetBytes("phase2-object-storage-payload")

    let uploadedKey = uploadObject client ct objectKey payload
    let downloaded = client.DownloadObject(uploadedKey, None, ct).Result |> requireOk
    Assert.Equal<byte>(payload, readAllBytes downloaded)

    let ranged = client.DownloadObject(uploadedKey, Some(3L, Some 8L), ct).Result |> requireOk
    Assert.Equal<byte>(payload.[3..8], readAllBytes ranged)

    client.DeleteObject(uploadedKey, ct).Result |> requireOk |> ignore
