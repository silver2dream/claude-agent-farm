# Upgrade Path: K3s → Cloud Kubernetes

Your Claude Agent Farm manifests are standard Kubernetes. Moving to a cloud provider requires minimal changes.

## What stays the same

- All Deployment YAMLs
- All PVC definitions
- All NetworkPolicy definitions
- All Secret structures
- The Makefile commands (swap `kubectl` context)

## What changes

| Item | K3s | Cloud (EKS/GKE/AKS) |
|---|---|---|
| `imagePullPolicy` | `Never` (local image) | `Always` or `IfNotPresent` (from ECR/GCR/ACR) |
| Image source | `docker save \| k3s ctr import` | Push to container registry |
| Storage class | `local-path` (default) | Cloud provider's default (gp3, pd-ssd, etc.) |
| NetworkPolicy enforcement | Requires Calico addon | Usually enforced by default |
| Secrets encryption | Manual setup | KMS integration (EKS: AWS KMS, GKE: Cloud KMS) |

## Steps

1. Push your container image to a registry (ECR, GCR, ACR, Docker Hub)
2. Update `image:` in agent YAMLs to point to the registry
3. Change `imagePullPolicy: Never` to `IfNotPresent`
4. Apply manifests to your cloud cluster: `kubectl apply -f manifests/`
5. Re-run first-time pairing for each agent

## Optional: Add ArgoCD for GitOps

Once on cloud K8s, push manifests to a Git repo and let ArgoCD sync them:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Then adding/removing agents becomes a Git commit instead of a `kubectl apply`.

## Optional: Add Argo Events for webhook routing

For flexible event routing (splitting GitHub events by repo, label, etc.):

```bash
kubectl create namespace argo-events
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
```

---

For enterprise deployment guidance (multi-tenant isolation, RBAC, audit logging, credential rotation), contact: [HAN LIN](https://github.com/silver2dream)
