# Garage Compatibility Report

Generated at: 2026-04-29T04:16:59Z

## Summary

- Result: PASS
- Started at: 2026-04-29T04:16:56Z
- Completed at: 2026-04-29T04:16:59Z
- Endpoint: http://127.0.0.1:3900
- Bucket: kublai-garage-compat
- Garage image: dxflrs/garage:v2.3.0
- Test filter: FullyQualifiedName~Object storage provider contract|FullyQualifiedName~Object storage client supports multipart upload and ranged download

## Coverage

- Garage single-node layout bootstrap
- Garage bucket creation
- Garage access key creation
- Bucket read/write/owner permission grant
- Provider availability check
- Missing-object NotFound mapping
- Invalid-range mapping
- Delete semantics
- Incomplete multipart upload abort semantics
- Object metadata and ETag behavior
- Kublai multipart upload start
- Presigned upload part PUT
- Multipart upload complete
- Full object download
- Ranged object download

## Remaining EGA-35 Gates

- Add backup/restore procedure for Garage metadata and data volumes.
- Document AGPLv3 distribution obligations before adopting Garage in supported
  release artifacts.
- Add kind and Helm dependency options after local compatibility remains stable.
