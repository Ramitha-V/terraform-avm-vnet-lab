# Terraform and IaC Lab: VNet with AVM and GitHub Actions

Automated Azure VNet deployment using Terraform, Azure Verified Modules (AVM),
remote state in Azure Storage, and a GitHub Actions CI/CD pipeline that
authenticates to Azure with OIDC workload identity federation and requires
human approval before apply.

## Why this lab exists

This lab demonstrates a secure and repeatable VNet deployment using Terraform,
Azure Verified Modules, remote state, GitHub Actions, OIDC authentication,
pre-deployment checks, and approval before apply. There are no long-lived Azure
credentials anywhere in this repository.

## Business scenario

A cloud engineering team must deploy a standard development VNet consistently
into an Azure landing-zone subscription. The customer requires reusable
Microsoft-aligned modules, centralized state, secure GitHub-to-Azure
authentication, pre-deployment checks, and human approval before infrastructure
changes are applied.

## Repository layout

```
terraform-avm-vnet-lab/
|-- .github/
|   `-- workflows/
|       `-- terraform-dev.yml    # plan, approval, and apply workflow
|-- infra/
|   `-- dev/
|       |-- backend.tf           # partial azurerm backend
|       |-- providers.tf         # Terraform and provider constraints
|       |-- main.tf              # resource group and AVM VNet module
|       |-- variables.tf         # typed configuration inputs
|       |-- outputs.tf           # deployment outputs
|       |-- .tflint.hcl          # TFLint rulesets
|       `-- terraform.tfvars.example
|-- .gitignore
`-- README.md
```

## Architecture

| Layer | Component |
| --- | --- |
| Source | This repository, `infra/dev` root module |
| Module | `Azure/avm-res-network-virtualnetwork/azurerm` pinned to `0.22.2` |
| State | Azure Storage blob container, partial backend supplied at `init` |
| Identity | Two Entra app registrations with GitHub federated credentials (no secrets) |
| Pipeline | `plan` job -> `dev-apply` approval gate -> `apply` job |

## Prerequisites

- GitHub repository with Actions enabled
- Azure subscription and required RBAC permissions
- Existing Azure Storage account and private container for Terraform state
- GitHub-to-Azure federated credentials (OIDC)
- GitHub environments `dev-plan` and `dev-apply`, with required reviewers on `dev-apply`
- Terraform CLI 1.9 or later, Azure CLI, and Git for local validation

## Identity model

Two identities are used so that plan cannot change infrastructure.

| Identity | Federated subjects | Azure RBAC |
| --- | --- | --- |
| `gh-tf-avm-vnet-lab-plan` | `repo:<owner>/<repo>:environment:dev-plan`, `repo:<owner>/<repo>:pull_request` | `Reader` on the subscription, `Storage Blob Data Contributor` on the state storage account |
| `gh-tf-avm-vnet-lab-apply` | `repo:<owner>/<repo>:environment:dev-apply`, `repo:<owner>/<repo>:ref:refs/heads/main` | `Contributor` on the subscription, `Storage Blob Data Contributor` on the state storage account |

## Required environment variables

Set these as **variables** (not secrets) on both the `dev-plan` and `dev-apply`
GitHub environments. `AZURE_CLIENT_ID` differs per environment because each
environment uses its own identity.

| Variable | Purpose |
| --- | --- |
| `AZURE_CLIENT_ID` | Application (client) ID of the environment's identity |
| `AZURE_TENANT_ID` | Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription |
| `TF_STATE_RESOURCE_GROUP` | Resource group holding the state storage account |
| `TF_STATE_STORAGE_ACCOUNT` | State storage account name |
| `TF_STATE_CONTAINER` | State blob container name |
| `TF_STATE_KEY` | State blob key, for example `network/dev.tfstate` |

This lab must not define `AZURE_CLIENT_SECRET`.

## Bootstrap the backend

Backend infrastructure must exist before `terraform init`. Never create the
state storage account in the same root module that uses it as a backend.

```bash
az group create --name rg-tfstate-dev --location centralindia

az storage account create \
  --name <globally-unique-name> \
  --resource-group rg-tfstate-dev \
  --location centralindia \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

az storage container create \
  --name tfstate \
  --account-name <globally-unique-name> \
  --auth-mode login
```

## Local initialization test

```bash
terraform -chdir=infra/dev init -reconfigure \
  -backend-config="resource_group_name=rg-tfstate-dev" \
  -backend-config="storage_account_name=<globally-unique-name>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=network/dev.tfstate" \
  -backend-config="use_azuread_auth=true"
```

## Run the lab

1. Configure the backend and OIDC prerequisites.
2. Commit the Terraform and workflow files to a feature branch.
3. Open a pull request and review all checks plus the Terraform plan.
4. Merge to `main` according to repository policy.
5. Run the workflow on `main` and approve the `dev-apply` environment.
6. Validate the VNet and subnets in Azure.
7. Rerun plan and confirm no unexpected changes.

## Pipeline design

| Stage | Key activities | Control |
| --- | --- | --- |
| Plan | Checkout, Azure OIDC login, setup Terraform, fmt, init, validate, TFLint, Trivy scan, plan, upload artifact | Runs on pull request or manual trigger with a read-focused identity |
| Approval | `dev-apply` environment waits for a required reviewer | Human verification of the saved Terraform plan |
| Apply | Checkout, login, init, download plan, apply | Runs only from `main` using the protected apply environment |

## Validate the deployment

```bash
az network vnet show \
  --resource-group rg-avm-vnet-dev \
  --name vnet-avm-dev \
  --query "{name:name,addressSpace:addressSpace.addressPrefixes,subnets:subnets[].name}" \
  --output jsonc
```

## Success criteria

- OIDC login succeeds without an Azure client secret.
- State is remote and excluded from Git.
- Format, validation, lint, security scan, and plan pass.
- Apply requires approval and deploys the AVM-based VNet.
- A repeat plan is stable and shows no unexpected changes.

## Troubleshooting

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| `azure/login`: no subscriptions found | Wrong tenant/subscription variables, or the identity has no role at the scope | Verify IDs, federated subject, tenant, and role assignment |
| `AADSTS70021` federated credential not found | OIDC subject, audience, issuer, branch, repo, or environment mismatch | Compare the job environment and ref to the federated credential exactly |
| `AuthorizationPermissionMismatch` on backend | Identity lacks blob data-plane access | Grant `Storage Blob Data Contributor` at the backend scope and allow propagation |
| Backend configuration changed | Stale local `.terraform` metadata | Run `terraform init -reconfigure` with the intended values |
| State lock error | Another run holds the lock | Wait for the active run; investigate before `force-unlock` |
| `terraform validate` fails after module change | Inputs do not match the pinned module version | Review the module README and changelog |
| `fmt` check fails | Files are not canonically formatted | Run `terraform fmt -recursive` and commit |
| TFLint or Trivy fails | Code violates lint or security policy | Correct the finding; document a justified exception instead of disabling the check |
| Apply cannot find `tfplan` | Artifact name/path mismatch or different workflow run | Keep plan and apply in the same run with matching names |
| Apply plan is stale | State or infrastructure changed after planning | Generate a new plan and repeat approval |
| Overlapping CIDR | Ranges conflict with existing networks | Confirm IP allocation and update `address_space` |

Never print credentials or Terraform state to logs.

## Safe retry rules

- Do not reuse a plan after configuration or state changes.
- Do not delete the remote state blob to fix a backend issue.
- Do not `force-unlock` state until no Terraform operation is active.
- Do not bypass validation, security scans, or the approval gate.
- After every fix, rerun Plan and verify expected actions before Apply.

## Cleanup

```bash
terraform -chdir=infra/dev destroy \
  -var="subscription_id=<subscription-id>"

az group delete --name rg-tfstate-dev --yes --no-wait
az ad app delete --id <plan-app-id>
az ad app delete --id <apply-app-id>
```

## References

- Azure Verified Modules portal: <https://azure.github.io/Azure-Verified-Modules/>
- AVM VNet Terraform Registry module: <https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm/latest>
- AVM VNet source repository: <https://github.com/Azure/terraform-azurerm-avm-res-network-virtualnetwork>
- GitHub Actions OIDC Terraform sample: <https://learn.microsoft.com/en-us/samples/azure-samples/github-terraform-oidc-ci-cd/github-terraform-oidc-ci-cd/>
