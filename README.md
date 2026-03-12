# Node.js Application - Production AKS Deployment

## Overview

This repository delivers a **production-grade, end-to-end DevOps implementation** of a Node.js REST API on **Azure Kubernetes Service (AKS)**. All cloud infrastructure is defined as code with **Terraform**, application delivery is managed via **Kubernetes manifests with Kustomize overlays**, and a **GitHub Actions CI/CD pipeline** enforces quality gates from commit to production.

Designed to demonstrate enterprise DevOps practices: security hardening, multi-environment promotion, infrastructure idempotency, observability, and GitOps workflow.

---

## Architecture Overview

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
│  │  │  ┌──────────────────┐  ┌──────────────────────────────────┐ │  │  │
│  │  │  │  snet-aks-nodes  │  │  snet-private-endpoints          │ │  │  │
│  │  │  │  10.0.1.0/24     │  │  10.0.6.0/24                     │ │  │  │
│  │  │  │                  │  │                                  │ │  │  │
│  │  │  │  ┌────────────┐  │  │  ┌─────────────────────────────┐ │ │  │  │
│  │  │  │  │AKS Cluster │  │  │  │ ACR Private Endpoint (prod) │ │ │  │  │
│  │  │  │  │            │  │  │  └─────────────────────────────┘ │ │  │  │
│  │  │  │  │ System Pool│  │  │                                  │ │  │  │
│  │  │  │  │ User Pool  │  │  └──────────────────────────────────┘ │  │  │
│  │  │  │  └────────────┘  │                                       │  │  │
│  │  │  └──────────────────┘                                       │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  │                                                                   │  │
│  │  ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │  │
│  │  │ ACR            │  │ Log Analytics    │  │ Managed Identity │   │  │
│  │  │ (Container     │  │ Workspace        │  │ (AKS Control     │   │  │
│  │  │  Registry)     │  │ (Monitoring)     │  │  Plane)          │   │  │
│  │  └────────────────┘  └──────────────────┘  └──────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘

CI/CD Flow:
  Git Push → CI (lint → test → npm audit → k8s validate → Trivy/Hadolint → ACR push)
           → CD Staging (auto, triggered by workflow_run on main)
           → CD Production (manual workflow_dispatch, separate trigger)
```

### Component Summary

| Component | Purpose |
|-----------|---------|
| **Azure AKS** | Managed Kubernetes cluster with system + user node pools, Azure AD RBAC, OIDC issuer |
| **Azure ACR** | Private container registry; Basic (staging), Premium + private endpoint (production) |
| **Azure VNet** | Network isolation: dedicated subnets for AKS nodes and private endpoints |
| **NSGs** | Subnet-level network security rules for AKS nodes |
| **Managed Identity** | Passwordless AKS-to-ACR authentication; no static credentials anywhere |
| **Log Analytics** | Container Insights for centralized logging and monitoring |
| **Kubernetes Manifests** | Kustomize-based delivery with base + per-environment overlays |
| **GitHub Actions** | CI/CD pipeline with hard quality gates before every deployment |

---

## Project Structure

```
├── Dockerfile                          # Multi-stage, non-root hardened container image
├── index.js                            # Node.js Express application entry point
├── package.json                        # Runtime + dev dependencies
├── package-lock.json                   # Locked dependency tree (committed)
├── deploy-demo.ps1                     # One-click end-to-end demo deployment script
├── .gitignore
├── LICENSE
│
├── tests/
│   └── app.test.js                     # Unit + integration tests (Jest + supertest)
│
├── terraform/                          # IaC - all Azure infrastructure
│   ├── versions.tf                     # Provider version pins + remote state backend
    ├── providers.tf                    # AzureRM provider configuration
│   ├── variables.tf                    # All configurable inputs with descriptions
│   ├── main.tf                         # Module composition and role assignments
│   ├── outputs.tf                      # Deployment outputs (cluster ID, ACR URL, etc.)
│   ├── terraform.tfvars.example        # Template - copy to terraform.tfvars and populate
│   ├── terraform.tfvars.demo           # Cost-optimised configuration used in demo deploy
│   ├── terraform-plan-output.txt       # Saved plan output (committed deliverable)
│   ├── .terraform.lock.hcl             # Provider dependency lock file (committed)
│   └── modules/
│       ├── networking/                 # VNet, Subnets, NSGs
│       ├── acr/                        # Azure Container Registry
│       └── aks/                        # AKS Cluster, Node Pools, Log Analytics
│
├── k8s/                                # Kubernetes manifests (Kustomize)
│   ├── base/                           # Environment-agnostic base resources
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml             # Deployment with security hardening and health probes
│   │   ├── service.yaml                # ClusterIP service
│   │   ├── hpa.yaml                    # Horizontal Pod Autoscaler
│   │   ├── pdb.yaml                    # Pod Disruption Budget
│   │   └── serviceaccount.yaml
│   └── overlays/
        ├── staging/                    # Staging: 2 replicas, debug logging
        └── production/                 # Production: 3 replicas, higher resource limits
│
└── .github/workflows/
    ├── ci.yml                          # CI: lint → test → audit → k8s validate → build+push → scan
    └── cd.yml                          # CD: staging auto-deploy (workflow_run) → production manual dispatch
```

---

## Prerequisites

### Tools Required

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Terraform | >= 1.6.0 | Infrastructure provisioning |
| Azure CLI | >= 2.55.0 | Azure authentication and management |
| kubectl | >= 1.33 | Kubernetes cluster interaction + kustomize |
| Docker | >= 24.0 | Container image building (local dev) |
| Node.js | >= 18.x | Application runtime (local dev) |

### Azure Requirements

- An active Azure subscription
- Permissions: **Contributor** + **User Access Administrator** on the subscription
  - Contributor creates all resources
  - User Access Administrator is required to assign roles (ACR pull for AKS, RBAC roles)
- A Storage Account for Terraform remote state (created by `deploy-demo.ps1` automatically)

### GitHub Actions Service Principal - Required Roles

The service principal used by GitHub Actions needs the following Azure RBAC roles before the CD pipeline can deploy to AKS:

| Role | Scope | Purpose |
|------|-------|---------|
| Contributor | Subscription | Create and manage Azure resources |
| AcrPush | ACR resource | Push container images from CI |
| **Azure Kubernetes Service RBAC Cluster Admin** | AKS cluster resource | `kubectl apply` access via Azure AD RBAC |

> **Note:** `Azure Kubernetes Service RBAC Cluster Admin` is required because the AKS cluster uses `azure_rbac_enabled = true` (Kubernetes RBAC is enforced through Azure RBAC, not a `kubeconfig` with admin credentials). Without this role, `kubectl apply` fails with `secrets is forbidden`.

To assign it:
```bash
az role assignment create \
  --assignee "<SP_OBJECT_ID>" \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope "/subscriptions/<SUB_ID>/resourceGroups/rg-nodejs-aks-staging/providers/Microsoft.ContainerService/managedClusters/aks-nodejs-staging"
```

This role assignment is also tracked in `terraform/main.tf` as `azurerm_role_assignment.github_actions_aks_admin` for full IaC coverage.

---

## Deployment

### Option A - Automated Demo Deploy (Recommended)

`deploy-demo.ps1` automates everything end-to-end in a single command:

```powershell
# Windows PowerShell - from repo root
.\deploy-demo.ps1
```

The script:
1. Creates the Terraform remote state backend (storage account + container)
2. Runs `terraform init`, `terraform plan`, and `terraform apply` using `terraform.tfvars.demo`
3. Retrieves AKS credentials and configures `kubelogin` for AAD auth
4. Builds and pushes the Docker image to ACR
5. Deploys the manifests to the staging namespace via `kubectl apply -k`

All resources are provisioned within a single Azure subscription using predictable naming conventions - no manual configuration steps required.

---

### Option B - Manual Step-by-Step Deployment

#### Step 1: Azure Authentication

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az account show --output table
```

#### Step 2: Create Terraform State Backend

```bash
# Create resource group for Terraform state
az group create --name rg-terraform-state --location eastus2

# Create storage account (name must be globally unique)
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

> Update `terraform/versions.tf` with your actual storage account name before running `terraform init`.

#### Step 3: Provision Infrastructure with Terraform

```bash
cd terraform

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your subscription ID and desired settings

# Initialize providers and backend
terraform init

# Review the execution plan
terraform plan -out=tfplan

# Save human-readable plan output
terraform show tfplan > terraform-plan-output.txt

# Apply
terraform apply tfplan
```

#### Step 4: Connect to AKS

```bash
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)

# Install kubelogin (required for Azure AD RBAC-enabled clusters)
az aks install-cli

# Convert kubeconfig for AAD authentication
kubelogin convert-kubeconfig -l azurecli

# Verify
kubectl get nodes
```

#### Step 5: Build and Push Docker Image

```bash
ACR_NAME=$(terraform output -raw acr_name)
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)

az acr login --name $ACR_NAME

docker build -t $ACR_LOGIN_SERVER/nodejs-app:v1.0.0 .
docker push $ACR_LOGIN_SERVER/nodejs-app:v1.0.0
```

#### Step 6: Deploy with kubectl

```bash
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
IMAGE_TAG=v1.0.0

# Stage: substitute image in the overlay, then apply
sed -i "s|REGISTRY_PLACEHOLDER|$ACR_LOGIN_SERVER/nodejs-app|g" k8s/overlays/staging/kustomization.yaml
sed -i "s|TAG_PLACEHOLDER|$IMAGE_TAG|g"                        k8s/overlays/staging/kustomization.yaml
kubectl apply -k k8s/overlays/staging

# Verify
kubectl rollout status deployment/nodejs-app -n nodejs-app-staging
kubectl get pods -n nodejs-app-staging
kubectl get svc  -n nodejs-app-staging
```

#### Step 7: Configure GitHub Actions

Set the following secret in your GitHub repository (Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|-------|
| `AZURE_CREDENTIALS` | JSON output from `az ad sp create-for-rbac --name "sp-github" --role Contributor --scopes /subscriptions/<SUB_ID> --sdk-auth` |

After creating the SP, assign the additional roles listed in the [Prerequisites](#github-actions-service-principal--required-roles) section.

All other values (ACR name, AKS cluster name, resource groups) are derived automatically from Azure resource tags and naming conventions at pipeline runtime - no additional secrets needed.

---

## CI/CD Pipeline

### CI Pipeline (`.github/workflows/ci.yml`)

Triggered on every push and pull request to `main`. Each stage is a hard gate - failure blocks the pipeline.

| Stage | Tool | Gate Condition |
|-------|------|---------------|
| **Lint** | node --check | Zero syntax errors |
| **Unit Tests** | Jest + supertest | All tests pass, coverage ≥ threshold |
| **npm audit** | npm audit | No high or critical vulnerabilities in dependencies |
| **K8s validate** | kubectl kustomize | Both overlays render without errors |
| **Build + Push** | docker/build-push-action | Image built and pushed to ACR (main branch only) |
| **Trivy scan** | aquasecurity/trivy-action | HIGH/CRITICAL CVEs uploaded to GitHub Security (non-blocking) |
| **Hadolint** | hadolint/hadolint-action | No Dockerfile violations at warning level or above |

### CD Pipeline (`.github/workflows/cd.yml`)

Triggered on successful completion of the CI pipeline on `main`.

```
CI passes on main
  → Staging deploy  (automatic, triggered by workflow_run)
  → Production deploy  (manual workflow_dispatch, separate trigger)
```

| Step | Detail |
|------|--------|
| **Staging deploy** | Automatic; uses `k8s/overlays/staging` (2 replicas, debug logging) |
| **kubelogin** | `azure/use-kubelogin@v1` converts kubeconfig for AAD-RBAC auth |
| **kubectl apply -k** | Kustomize overlay rendered and applied; `kubectl rollout status` waits for readiness |
| **Production trigger** | Manual `workflow_dispatch` with `environment=production`; configure GitHub environment protection rules with required reviewers for additional approval enforcement |
| **Production deploy** | Uses `k8s/overlays/production` (3 replicas, higher resource limits) |

### Test Coverage

```bash
npm test           # Run Jest tests with coverage report
npm run lint       # Run Node.js syntax check
npm audit          # Dependency vulnerability scan
```

Current test coverage: **81%** (statements). Tests cover the Express route handlers using `supertest` for HTTP-level assertions.

---

## Key Assumptions

1. **Cloud Provider:** Azure - AKS, ACR, VNet, Managed Identity, Log Analytics.
2. **Kubernetes Version:** Auto-detected to latest stable (currently `1.34.x`); auto-upgrade set to `patch` channel.
3. **Container Registry:** Azure Container Registry - **Basic SKU** (staging), **Premium SKU with private endpoint** (production).
4. **Networking:** Azure CNI - pods receive real VNet IPs, enabling pod-level NSG and network policy enforcement.
5. **Node Pools:** Separate system (tainted `CriticalAddonsOnly`) and user node pools for workload isolation.
6. **VM Size:** `Standard_D2s_v3` (2 vCPU / 8 GiB) - cost-optimised for demo; scale up in production via `terraform.tfvars`.
7. **Autoscaling:** Cluster Autoscaler (CA) for node scaling + HPA for pod scaling.
8. **Key Vault CSI Driver:** The Secrets Store CSI Driver add-on is installed on the AKS cluster, enabling pods to mount Azure Key Vault secrets as volumes. Secret mounts are not required by this application but the infrastructure supports it.
9. **Service Exposure:** The application service is `ClusterIP` (cluster-internal only). Ingress controllers and external DNS are environment-specific and outside the scope of this repository.
10. **Production Authorization:** The `production` GitHub Actions environment should be configured with required reviewers in GitHub repository settings to enforce human approval before production deployments execute.
11. **CI/CD Auth:** GitHub Actions authenticates to Azure via a service principal with `AZURE_CREDENTIALS` secret; no long-lived passwords or tokens elsewhere.
12. **AKS RBAC:** `azure_rbac_enabled = true` - Kubernetes RBAC permissions are managed through Azure RBAC role assignments, not `kubeconfig` cluster-admin credentials.

---

## Security Posture

| Control | Implementation |
|---------|---------------|
| **Non-root container** | Dockerfile creates `nodeapp` user (UID 1001) |
| **Read-only root FS** | `readOnlyRootFilesystem: true` in security context |
| **No privilege escalation** | `allowPrivilegeEscalation: false` |
| **Capabilities dropped** | All Linux capabilities dropped |
| **Seccomp profile** | `RuntimeDefault` seccomp profile enabled |
| **Azure Network Policy** | Azure Network Policy Manager (NPM) enabled on cluster (`network_policy = "azure"`); enforces NetworkPolicy resources at the CNI layer |
| **Private ACR** | Private endpoint in production; no public registry access |
| **Managed Identity** | No passwords - AKS authenticates to ACR via managed identity |
| **Image scanning** | Trivy vulnerability scanner in CI pipeline |
| **Pod Disruption Budget** | Ensures availability during rolling updates and node drains |
| **RBAC** | Azure AD integration with Kubernetes RBAC |

---

## Monitoring & Observability

- **Azure Monitor Container Insights** - enabled via Log Analytics workspace
- **Kubernetes health probes:**
  - **Liveness:** Restarts unhealthy containers (`/health`)
  - **Readiness:** Removes pods from service endpoints when not ready (`/health`)
  - **Startup:** Prevents premature liveness kills during boot
- **Resource limits** - CPU/memory requests and limits prevent resource starvation
- **Log retention** - 30 days (staging), 90 days (production)

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

**Deployment stuck / pods not ready:**
```bash
# Check pod status and events
kubectl get pods -n <namespace> -o wide
kubectl describe pods -n <namespace>

# Check rollout status
kubectl rollout status deployment/nodejs-app -n <namespace>

# Roll back to previous version
kubectl rollout undo deployment/nodejs-app -n <namespace>
```

**Terraform state lock:**
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

---

## Cleanup

```bash
# Remove deployed resources
kubectl delete -k k8s/overlays/staging   || true
kubectl delete -k k8s/overlays/production || true

# Destroy infrastructure
cd terraform
terraform destroy

# Remove Terraform state backend (optional)
az group delete --name rg-terraform-state --yes
```

---

## License

MIT