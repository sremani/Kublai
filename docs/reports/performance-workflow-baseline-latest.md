# Performance Workflow Baseline Report

Generated at: 2026-05-10T21:38:35Z

## Summary

- overall status: PASS
- upload/download reference report: `docs/reports/phase2-load-baseline-latest.md`

## Results

| Workload | Status | Operation count | Operation label | Elapsed (ms) | Ops/sec |
|---|---|---:|---|---:|---:|
| ER-701 publish workflow baseline batch completes | PASS | 24 | publish completions | 1803 | 13.31 |
| ER-701 search query baseline batch completes | PASS | 72 | search queries | 1923 | 37.44 |
| ER-701 quarantine workflow baseline batch completes | PASS | 30 | quarantine workflow operations | 1662 | 18.05 |

## Reproduce

```bash
make build
make test-integration
make performance-workflow-baseline
```
