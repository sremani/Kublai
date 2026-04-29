# HA Kubernetes Validation Report

Generated at: 2026-04-29T04:53:52Z

## Summary

- overall status: PASS
- started at: 2026-04-29T04:50:42Z
- ended at: 2026-04-29T04:53:52Z
- cluster: kublai-ha
- namespace: kublai-ha-validation
- release: kublai
- object storage provider: garage
- object storage endpoint: http://garage:3900
- object storage bucket: kublai-dev
- API ready replicas: 3
- worker ready replicas: 2

## Tooling

```text
kind v0.31.0 go1.25.5 linux/amd64
v4.1.4+g05fa379
Client Version: v1.36.0
Kustomize Version: v5.8.1
Server Version: v1.35.0
```

## Validated Scenarios

- kind cluster creation or reuse
- local API and worker image builds
- image load into kind nodes
- in-cluster Postgres dependency startup
- selected object-storage dependency startup: garage
- selected object-storage bucket bootstrap: kublai-dev
- SQL migrations applied through current head
- Helm install/upgrade
- API and worker rollout readiness
- API liveness/readiness over port-forward
- production preflight with Kubernetes and Helm checks
- API and worker rolling restart
- worker scale-down and restore
- API scale-down and restore

## Pod Placement

```text
NAME                             READY   STATUS    RESTARTS   AGE     IP            NODE                      NOMINATED NODE   READINESS GATES
garage-5bf596c9c-4x9c8           1/1     Running   0          3m10s   10.244.2.8    kublai-ha-worker2   <none>           <none>
kublai-api-79db9f4959-gmwpf      1/1     Running   0          12s     10.244.1.21   kublai-ha-worker    <none>           <none>
kublai-api-79db9f4959-hlcw6      1/1     Running   0          12s     10.244.1.20   kublai-ha-worker    <none>           <none>
kublai-api-79db9f4959-sjt6z      1/1     Running   0          2m37s   10.244.2.12   kublai-ha-worker2   <none>           <none>
kublai-worker-6459b564ff-7xp2f   1/1     Running   0          13s     10.244.1.19   kublai-ha-worker    <none>           <none>
kublai-worker-6459b564ff-nlj7c   1/1     Running   0          13s     10.244.2.13   kublai-ha-worker2   <none>           <none>
postgres-7877bd4588-t8nqr        1/1     Running   0          16m     10.244.1.12   kublai-ha-worker    <none>           <none>
```

## Production Preflight

- report: `/tmp/kublai-kind-production-preflight.md`

## Residual Risks

- validation uses local kind infrastructure, not managed cloud Kubernetes
- Postgres and in-cluster object storage are single-replica validation dependencies
- ingress/TLS is not validated in the kind path
- production capacity is not certified by this validation
