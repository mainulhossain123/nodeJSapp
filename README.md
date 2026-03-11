# Node.js Application — Production AKS Deployment

## Architecture Overview

This repository contains a production-grade deployment of a Node.js REST API on **Azure Kubernetes Service (AKS)**, provisioned with **Terraform** and deployed via **Helm charts** through a **GitHub Actions CI/CD pipeline**.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                               │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │               Resource Group: rg-nodejs-aks-<env>                 │  │
│  │                                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │            VNet: vnet-nodejs-<env> (10.0.0.0/16)            │  │  │
│  │  │                                                             │  │  │
│  │  │  ┌──────────────────┐  ┌──────────────────────────────────┐│  │  │
│  │  │  │  snet-aks-nodes  │  │  snet-private-endpoints          ││  │  │
│  │  │  │  10.0.1.0/24     │  │  10.0.6.0/24                     ││  │  │
│  │  │  │                  │  │                                   ││  │  │
│  │  │  │  ┌────────────┐  │  │  ┌─────────────────────────────┐ ││  │  │
│  │  │  │  │AKS Cluster │  │  │  │ ACR Private Endpoint (prod) │ ││  │  │
│  │  │  │  │            │  │  │  └─────────────────────────────┘ ││  │  │
│  │  │  │  │ System Pool│  │  │                                   ││  │  │
│  │  │  │  │ User Pool  │  │  └──────────────────────────────────┘│  │  │
│  │  │  │  └────────────┘  │                                       │  │  │
│  │  │  └──────────────────┘                                       │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  │                                                                   │  │
│  │  ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │  │
│  │  │ ACR            │  │ Log Analytics    │  │ Managed Identity │  │  │
│  │  │ (Container     │  │ Workspace        │  │ (AKS Control     │  │  │
│  │  │  Registry)     │  │ (Monitoring)     │  │  Plane)          │  │  │
│  │  └────────────────┘  └──────────────────┘  └──────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘

CI/CD Flow:
  GitHub Push → CI (lint/test/build/scan) → ACR → CD (Helm deploy) → AKS
```

### Component Summary

| Component | Purpose |
|-----------|---------|
| **Azure AKS** | Managed Kubernetes cluster with system + user node pools |
| **Azure ACR** | Private container registry with vulnerability scanning |
| **Azure VNet** | Network isolation with dedicated subnets |
| **NSGs** | Network security rules for AKS nodes |
| **Managed Identity** | Passwordless authentication between AKS and ACR |
| **Log Analytics** | Centralized logging and monitoring via Container Insights |
| **Helm Charts** | Templated Kubernetes deployment with environment overrides |
| **GitHub Actions** | CI/CD pipeline for automated build, scan, and deploy |

---

## Project Structure

```
├── Dockerfile                          # Multi-stage, hardened container image
├── index.js                            # Node.js application entry point
├── package.json                        # Node.js dependencies
├── deploy-demo.ps1                     # One-click automated deployment script
├── .gitignore                          # Git ignore rules
│
├── terraform/                          # IaC — Azure infrastructure
│   ├── versions.tf                     # Provider version pins + backend config
│   ├── providers.tf                    # AzureRM, Kubernetes, Helm providers
│   ├── variables.tf                    # All configurable inputs
│   ├── main.tf                         # Module composition (root)
│   ├── outputs.tf                      # Deployment outputs
│   ├── terraform.tfvars.example        # Example variable values
│   ├── terraform.tfvars.demo           # Cost-optimised demo configuration
│   └── modules/
│       ├── networking/                 # VNet, Subnets, NSGs
│       ├── acr/                        # Azure Container Registry
│       └── aks/                        # AKS Cluster + Node Pools
│
├── helm/
│   └── nodejs-app/                     # Helm chart
│       ├── Chart.yaml
│       ├── values.yaml                 # Default values
│       ├── values-staging.yaml         # Staging overrides
│       ├── values-production.yaml      # Production overrides
│       └── templates/                  # K8s resource templates
│
├── k8s/                                # Raw manifests (reference/fallback)
│
└── .github/workflows/
    ├── ci.yml                          # Build, test, scan, push
    └── cd.yml                          # Deploy to staging/production
```

---

## Prerequisites

### Tools Required

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | >= 1.6.0 | Infrastructure provisioning |
| Azure CLI | >= 2.55.0 | Azure authentication and management |
| kubectl | >= 1.33 | Kubernetes cluster interaction |
| Helm | >= 3.14.0 | Kubernetes package management |
| Docker | >= 24.0 | Container image building |
| Node.js | >= 18.x | Application runtime (local dev) |

### Azure Requirements

- An active Azure subscription
- Permissions: Contributor + User Access Administrator on the subscription
- A Storage Account for Terraform state (see setup below)

---

## Step-by-Step Deployment

### Step 1: Azure Authentication

```bash
# Login to Azure
az login

# Set the target subscription
az account set --subscription "<SUBSCRIPTION_ID>"

# Verify
az account show --output table
```

### Step 2: Create Terraform State Backend

```bash
# Create resource group for Terraform state
az group create --name rg-terraform-state --location eastus2

# Create storage account (must be globally unique)
az storage account create \
  --name stterraformstate<unique> \
  --resource-group rg-terraform-state \
  --sku Standard_LRS \
  --encryption-services blob

# Create blob container
az storage container create \
  --name tfstate \
  --account-name stterraformstate<unique>
```

> **Important:** Update `terraform/versions.tf` with your actual storage account name.

### Step 3: Provision Infrastructure with Terraform

```bash
cd terraform

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize Terraform (downloads providers, configures backend)
terraform init

# Review the execution plan
terraform plan -out=tfplan

# Save the human-readable plan output (required deliverable)
terraform show tfplan > terraform-plan-output.txt

# Apply the infrastructure
terraform apply tfplan

# Save outputs for later use
terraform output -json > ../terraform-outputs.json
```

### Step 4: Connect to AKS

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)

# Verify connectivity
kubectl get nodes
kubectl get namespaces
```

### Step 5: Build and Push Docker Image

```bash
# Get ACR login server from Terraform output
ACR_NAME=$(terraform output -raw acr_name)
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)

# Login to ACR
az acr login --name $ACR_NAME

# Build the image
docker build -t $ACR_LOGIN_SERVER/nodejs-app:v1.0.0 .

# Push to ACR
docker push $ACR_LOGIN_SERVER/nodejs-app:v1.0.0
```

### Step 6: Deploy with Helm

```bash
# Deploy to staging
helm upgrade --install nodejs-app helm/nodejs-app \
  --namespace nodejs-app-staging \
  --create-namespace \
  --values helm/nodejs-app/values.yaml \
  --values helm/nodejs-app/values-staging.yaml \
  --set image.repository=$ACR_LOGIN_SERVER/nodejs-app \
  --set image.tag=v1.0.0 \
  --wait

# Verify deployment
kubectl get pods -n nodejs-app-staging
kubectl get svc -n nodejs-app-staging
helm list -n nodejs-app-staging
```

### Step 7: Configure CI/CD (GitHub Actions)

Set the following secrets in your GitHub repository (Settings → Secrets → Actions):

| Secret | Value | How to get it |
|--------|-------|---------------|
| `AZURE_CREDENTIALS` | Service principal JSON | `az ad sp create-for-rbac --name "sp-nodejs-aks-github" --role Contributor --scopes /subscriptions/<SUB_ID> --sdk-auth` |

That is the **only** secret required. Everything else is derived automatically:

| Value | How it's resolved |
|-------|-------------------|
| ACR name & login server | Queried at runtime: `az acr list --resource-group rg-nodejs-aks-staging` |
| AKS cluster name | Derived from naming convention: `aks-nodejs-<environment>` |
| Resource group | Derived from naming convention: `rg-nodejs-aks-<environment>` |

> **Why this works:** Terraform uses a deterministic naming convention for all resources, and the ACR name uses the first 8 characters of your subscription ID as a suffix (globally unique, always predictable). No manual lookups needed after `terraform apply`.

---

## Key Assumptions

1. **Cloud Provider:** Azure is the chosen cloud provider (Azure AKS, ACR, VNet).
2. **Kubernetes Version:** Auto-detected to latest stable (currently 1.34); auto-upgrade set to patch level only.
3. **Container Registry:** Azure Container Registry (Premium SKU) with private endpoint in production.
4. **Networking:** Azure CNI networking for pod-level network policy enforcement.
5. **Node Pools:** Separate system and user node pools with taints for workload isolation.
6. **Autoscaling:** Cluster autoscaler (nodes) + HPA (pods) for horizontal scaling.
7. **Secrets:** Azure Key Vault CSI Driver for secret injection (configured but not enabled by default).
8. **TLS:** cert-manager with Let's Encrypt for automated TLS certificate management.
9. **Ingress:** NGINX Ingress Controller assumed to be installed on the cluster.
10. **CI/CD:** GitHub Actions with staging auto-deploy and production manual approval gate.

---

## Security Posture

| Control | Implementation |
|---------|---------------|
| **Non-root container** | Dockerfile creates `nodeapp` user (UID 1001) |
| **Read-only root FS** | `readOnlyRootFilesystem: true` in security context |
| **No privilege escalation** | `allowPrivilegeEscalation: false` |
| **Capabilities dropped** | All Linux capabilities dropped |
| **Seccomp profile** | `RuntimeDefault` seccomp profile enabled |
| **Network policies** | Zero-trust networking with explicit allow rules |
| **Private ACR** | Private endpoint in production; no public registry access |
| **Managed Identity** | No passwords — AKS authenticates to ACR via managed identity |
| **Image scanning** | Trivy vulnerability scanner in CI pipeline |
| **Pod Disruption Budget** | Ensures availability during rolling updates and node drains |
| **RBAC** | Azure AD integration with Kubernetes RBAC |

---

## Monitoring & Observability

- **Azure Monitor Container Insights** — enabled via Log Analytics workspace
- **Kubernetes health probes:**
  - **Liveness:** Restarts unhealthy containers (`/health`)
  - **Readiness:** Removes pods from service endpoints when not ready (`/health`)
  - **Startup:** Prevents premature liveness kills during boot
- **Resource limits** — CPU/memory requests and limits prevent resource starvation
- **Log retention** — 30 days (staging), 90 days (production)

---

## Troubleshooting

### Common Issues

**ImagePullBackOff:**
```bash
# Check if AKS has ACR pull permissions
az aks check-acr --resource-group <rg> --name <aks-name> --acr <acr-name>
```

**Pod CrashLoopBackOff:**
```bash
# Check pod logs
kubectl logs -n <namespace> <pod-name> --previous
# Check pod events
kubectl describe pod -n <namespace> <pod-name>
```

**Helm deployment stuck:**
```bash
# Check Helm release status
helm status nodejs-app -n <namespace>
# Rollback if needed
helm rollback nodejs-app -n <namespace>
```

**Terraform state lock:**
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

---

## Cleanup

```bash
# Remove Helm releases
helm uninstall nodejs-app -n nodejs-app-staging
helm uninstall nodejs-app -n nodejs-app-production

# Destroy infrastructure
cd terraform
terraform destroy

# Remove Terraform state backend (optional)
az group delete --name rg-terraform-state --yes
```

---

## License

MIT