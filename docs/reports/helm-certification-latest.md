# Helm Certification Report

Generated at: 2026-04-29T04:54:47Z

## Summary

- overall status: PASS
- started at: 2026-04-29T04:54:09Z
- ended at: 2026-04-29T04:54:47Z
- cluster: kublai-ha
- namespace: kublai-helm-cert
- release: kublai
- baseline chart: deploy/helm/kublai
- baseline chart version: 0.1.0
- target chart: deploy/helm/kublai
- target chart version: 0.1.0
- object storage provider: garage
- object storage endpoint: http://garage:3900
- object storage bucket: kublai-dev
- API ready replicas after upgrade: 3
- worker ready replicas after upgrade: 2

## Tooling

```text
kind v0.31.0 go1.25.5 linux/amd64
v4.1.4+g05fa379
Client Version: v1.36.0
Kustomize Version: v5.8.1
Server Version: v1.35.0
```

## Validated Scenarios

- Helm lint with kind HA values
- selected object-storage dependency startup: garage
- selected object-storage bucket bootstrap: kublai-dev
- baseline Helm install into kind Kubernetes
- API and worker rollout readiness after install
- API liveness and readiness smoke
- authenticated admin smoke
- repository create/read smoke
- production preflight with Kubernetes and Helm checks after install
- Helm upgrade to target chart values
- API and worker rollout readiness after upgrade
- API liveness and readiness smoke after upgrade
- authenticated admin smoke after upgrade
- repository create/read smoke after upgrade
- production preflight with Kubernetes and Helm checks after upgrade
- Helm uninstall
- uninstall cleanup check for Helm-owned Kublai resources
- data dependency preservation for Postgres and selected object-storage resources

## Helm History

```text
REVISION  UPDATED                   STATUS      CHART         APP VERSION  DESCRIPTION
1         Tue Apr 28 23:54:18 2026  superseded  kublai-0.1.0  latest       Install complete
2         Tue Apr 28 23:54:33 2026  deployed    kublai-0.1.0  latest       Upgrade complete
```

## Pod Placement Before Uninstall

```text
NAME                             READY   STATUS    RESTARTS   AGE   IP            NODE                      NOMINATED NODE   READINESS GATES
garage-5bf596c9c-2825s           1/1     Running   0          35s   10.244.2.14   kublai-ha-worker2   <none>           <none>
kublai-api-788d8947c-7g7bw       1/1     Running   0          28s   10.244.2.15   kublai-ha-worker2   <none>           <none>
kublai-api-788d8947c-7wdw2       1/1     Running   0          28s   10.244.1.24   kublai-ha-worker    <none>           <none>
kublai-api-788d8947c-zvtvb       1/1     Running   0          12s   10.244.2.16   kublai-ha-worker2   <none>           <none>
kublai-worker-586d5f6f85-c7wph   1/1     Running   0          28s   10.244.1.23   kublai-ha-worker    <none>           <none>
kublai-worker-586d5f6f85-d5jsq   1/1     Running   0          12s   10.244.2.17   kublai-ha-worker2   <none>           <none>
postgres-7877bd4588-hq4t2        1/1     Running   0          36s   10.244.1.22   kublai-ha-worker    <none>           <none>
```

## Preserved Data Dependencies After Uninstall

```text
deployment.apps/garage
deployment.apps/postgres
```

## Preflight Reports

- baseline: `/tmp/kublai-helm-cert-preflight-baseline.md`
- upgrade: `/tmp/kublai-helm-cert-preflight-upgrade.md`

## Residual Risks

- default baseline chart path is the current chart unless
  `HELM_CERT_BASE_CHART` points to a previous released chart package
- validation uses local kind infrastructure, not managed cloud Kubernetes
- Postgres and in-cluster object storage are single-replica validation dependencies
- ingress/TLS is not validated in the kind certification path
