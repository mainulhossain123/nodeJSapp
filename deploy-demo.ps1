# deploy-demo.ps1 — One-click demo deployment script
#
# What this script does (in order):
#   1.  Verify you are logged in to Azure
#   2.  Create the Terraform state backend (storage account + container)
#       — This is the ONE thing that cannot be done by Terraform itself
#         because Terraform needs somewhere to store state before it can run.
#   3.  Update terraform/versions.tf with the actual storage account name
#   4.  Copy terraform.tfvars.demo → terraform.tfvars
#   5.  Auto-detect the latest stable Kubernetes version for your region
#   6.  Run: terraform init
#   7.  Run: terraform plan  -out=tfplan   (generates real plan output)
#   8.  Run: terraform show  tfplan > terraform-plan-output.txt  (deliverable)
#   9.  Run: terraform apply tfplan        (provisions all Azure infrastructure)
#   10. Print all Terraform outputs (cluster name, ACR name, etc.)
#
# Usage:
#   cd E:\project\repos\nodeJSapp
#   .\deploy-demo.ps1
#
# To destroy everything when done:
#   cd terraform && terraform destroy

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Helpers ──────────────────────────────────────────────────────────────────
function Write-Step($n, $msg) {
    Write-Host ""
    Write-Host "[$n] $msg" -ForegroundColor Cyan
    Write-Host ("-" * 60) -ForegroundColor DarkGray
}

function Write-Success($msg) { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Fail($msg)    { Write-Host "  FAIL $msg" -ForegroundColor Red ; exit 1 }

# ─── Config ───────────────────────────────────────────────────────────────────
$REPO_ROOT          = $PSScriptRoot
$TERRAFORM_DIR      = Join-Path $REPO_ROOT "terraform"
$STATE_RG           = "rg-terraform-state"
$STATE_LOCATION     = "eastus2"
# Storage account name: lowercase, no hyphens, 3-24 chars, globally unique
# Uses "stmh" prefix + first 8 chars of subscription ID for uniqueness
$TFVARS_SRC         = Join-Path $TERRAFORM_DIR "terraform.tfvars.demo"
$TFVARS_DST         = Join-Path $TERRAFORM_DIR "terraform.tfvars"
$VERSIONS_TF        = Join-Path $TERRAFORM_DIR "versions.tf"
$PLAN_FILE          = Join-Path $TERRAFORM_DIR "tfplan"
$PLAN_OUTPUT        = Join-Path $TERRAFORM_DIR "terraform-plan-output.txt"

# ─── Step 1: Verify Azure login ───────────────────────────────────────────────
Write-Step 1 "Verifying Azure login"
try {
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $account) { throw }
    Write-Success "Logged in as: $($account.user.name)"
    Write-Success "Subscription: $($account.name) ($($account.id))"
    $SUBSCRIPTION_ID = $account.id
} catch {
    Write-Fail "Not logged in to Azure. Run: az login"
}

# ─── Step 2: Create Terraform state backend ───────────────────────────────────
Write-Step 2 "Creating Terraform state backend (one-time bootstrap)"
Write-Host "  NOTE: This is the only resource created outside of Terraform." -ForegroundColor Yellow
Write-Host "        Terraform needs a storage account to exist before it can store state." -ForegroundColor Yellow

# Derive a deterministic, unique storage account name from subscription ID
$subIdClean    = $SUBSCRIPTION_ID.Replace("-", "")
$STATE_ACCOUNT = "stterraform$($subIdClean.Substring(0, 8))"
Write-Host "  State storage account name: $STATE_ACCOUNT"

# Create resource group (idempotent — safe to re-run)
Write-Host "  Creating resource group: $STATE_RG"
az group create `
    --name $STATE_RG `
    --location $STATE_LOCATION `
    --output none

# Create storage account (idempotent — safe to re-run)
Write-Host "  Creating storage account: $STATE_ACCOUNT"
az storage account create `
    --name $STATE_ACCOUNT `
    --resource-group $STATE_RG `
    --sku Standard_LRS `
    --location $STATE_LOCATION `
    --allow-blob-public-access false `
    --output none

# Create blob container (idempotent — safe to re-run)
Write-Host "  Creating blob container: tfstate"
az storage container create `
    --name tfstate `
    --account-name $STATE_ACCOUNT `
    --output none

Write-Success "State backend ready: $STATE_ACCOUNT/tfstate"

# ─── Step 3: Update versions.tf with actual storage account name ──────────────
Write-Step 3 "Updating terraform/versions.tf with storage account name"
$versionsContent = Get-Content $VERSIONS_TF -Raw
$versionsContent = $versionsContent -replace 'storage_account_name\s*=\s*"[^"]*"', "storage_account_name = `"$STATE_ACCOUNT`""
Set-Content $VERSIONS_TF $versionsContent -NoNewline
Write-Success "versions.tf updated: storage_account_name = `"$STATE_ACCOUNT`""

# ─── Step 4: Copy demo tfvars ────────────────────────────────────────────────
Write-Step 4 "Copying terraform.tfvars.demo → terraform.tfvars"
Copy-Item $TFVARS_SRC $TFVARS_DST -Force
Write-Success "terraform.tfvars ready"

# ─── Step 5: Auto-detect latest stable Kubernetes version ────────────────────
Write-Step 5 "Auto-detecting latest stable Kubernetes version in eastus2"
try {
    $k8sVersions = az aks get-versions `
        --location $STATE_LOCATION `
        --query "values[?isPreview==null] | sort_by(@, &version) | [-1].version" `
        --output tsv 2>$null
    if ($k8sVersions) {
        Write-Success "Latest stable version: $k8sVersions"
        # Update terraform.tfvars with detected version
        $tfvarsContent = Get-Content $TFVARS_DST -Raw
        $tfvarsContent = $tfvarsContent -replace 'kubernetes_version\s*=\s*"[^"]*"', "kubernetes_version = `"$k8sVersions`""
        Set-Content $TFVARS_DST $tfvarsContent -NoNewline
        Write-Success "terraform.tfvars updated: kubernetes_version = `"$k8sVersions`""
    }
} catch {
    Write-Host "  Could not auto-detect K8s version — using value from tfvars" -ForegroundColor Yellow
}

# ─── Step 6: Terraform init ──────────────────────────────────────────────────
Write-Step 6 "Running: terraform init"
Push-Location $TERRAFORM_DIR
try {
    # -upgrade: re-resolves provider versions against updated constraints in versions.tf.
    # This is needed when provider version constraints change (e.g., azurerm 3.85 -> latest 3.x).
    terraform init -upgrade
    if ($LASTEXITCODE -ne 0) { Write-Fail "terraform init failed" }
    Write-Success "Terraform initialized successfully"

    # ─── Step 7: Terraform plan ──────────────────────────────────────────────
    Write-Step 7 "Running: terraform plan"
    terraform plan -out tfplan
    if ($LASTEXITCODE -ne 0) { Write-Fail "terraform plan failed" }
    Write-Success "Plan generated: tfplan"

    # ─── Step 8: Capture plan output (deliverable) ───────────────────────────
    Write-Step 8 "Capturing plan output → terraform-plan-output.txt"
    terraform show tfplan > $PLAN_OUTPUT
    Write-Success "Plan output saved: terraform/terraform-plan-output.txt"

    # ─── Step 9: Terraform apply ─────────────────────────────────────────────
    Write-Step 9 "Running: terraform apply  (this takes 10-15 minutes)"
    Write-Host "  Provisioning: VNet, NSGs, ACR, Managed Identity, AKS cluster, node pools..." -ForegroundColor Yellow
    terraform apply tfplan
    if ($LASTEXITCODE -ne 0) { Write-Fail "terraform apply failed" }
    Write-Success "Infrastructure provisioned successfully"

    # ─── Step 10: Print outputs ──────────────────────────────────────────────
    Write-Step 10 "Terraform outputs"
    terraform output
    Write-Host ""
    Write-Host "  To connect kubectl to your new cluster, run:" -ForegroundColor Cyan
    $rgName  = terraform output -raw resource_group_name
    $aksName = terraform output -raw aks_cluster_name
    Write-Host "  az aks get-credentials --resource-group $rgName --name $aksName" -ForegroundColor White

} finally {
    Pop-Location
}

# ─── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Green
Write-Host "  Deployment complete!" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "  1. Push this repo to GitHub to trigger the CI/CD pipeline"
Write-Host "  2. CI will build the Docker image and push it to ACR"
Write-Host "  3. CD will deploy the app to your AKS cluster via Helm"
Write-Host ""
Write-Host "  To destroy all resources when done:" -ForegroundColor Yellow
Write-Host "  cd terraform && terraform destroy"
Write-Host ""
