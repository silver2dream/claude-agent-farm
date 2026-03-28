[English](UPGRADE.md) | **繁體中文**

# 升級路徑：K3s → 雲端 Kubernetes

你的 Claude Agent Farm 清單檔是標準 Kubernetes 格式。遷移到雲端供應商只需最少的修改。

## 不需要改的部分

- 所有 Deployment YAML
- 所有 PVC 定義
- 所有 NetworkPolicy 定義
- 所有 Secret 結構
- Makefile 指令（切換 `kubectl` context 即可）

## 需要修改的部分

| 項目 | K3s | 雲端（EKS/GKE/AKS） |
|---|---|---|
| `imagePullPolicy` | `Never`（本機映像） | `Always` 或 `IfNotPresent`（從 ECR/GCR/ACR 拉取） |
| 映像來源 | `docker save \| k3s ctr import` | 推送到容器登錄檔 |
| 儲存類別 | `local-path`（預設） | 雲端供應商預設（gp3、pd-ssd 等） |
| NetworkPolicy 執行 | 需要 Calico 附加元件 | 通常預設即已強制執行 |
| Secrets 加密 | 手動設定 | KMS 整合（EKS: AWS KMS、GKE: Cloud KMS） |

## 步驟

1. 將你的容器映像推送到登錄檔（ECR、GCR、ACR、Docker Hub）
2. 更新智能體 YAML 中的 `image:` 指向登錄檔
3. 將 `imagePullPolicy: Never` 改為 `IfNotPresent`
4. 將清單套用到你的雲端叢集：`kubectl apply -f manifests/`
5. 為每個智能體重新執行首次配對

## 選用：加入 ArgoCD 實現 GitOps

上雲端 K8s 後，將清單推送到 Git 儲存庫，讓 ArgoCD 自動同步：

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

這樣新增/移除智能體就變成一次 Git commit，而非手動 `kubectl apply`。

## 選用：加入 Argo Events 做 Webhook 路由

如需靈活的事件路由（依 repo、label 等分流 GitHub 事件）：

```bash
kubectl create namespace argo-events
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
```

---

如需企業級部署指導（多租戶隔離、RBAC、稽核日誌、憑證輪換），請聯繫：[HAN LIN](https://github.com/silver2dream)
