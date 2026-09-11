# Submission evidence

This folder holds the completion evidence for the lab.

- `Terraform_AVM_VNet_GitHub_Actions_Lab_Submission.docx` — full submission report
  (architecture, identity model, pipeline design, run-by-run evidence, issue log,
  completion checklist, teardown steps).
- `evidence/` — the raw screenshots referenced by the report.

| File | Shows |
| --- | --- |
| `01-approval-gate-waiting.png` | Run #6 held at the `dev-apply` approval gate, plan green, artifact produced |
| `02-apply-run-success.png` | Run #6 succeeded, with the recorded reviewer approval |
| `03-idempotency-no-changes.png` | Run #7 succeeded with a no-change plan |
| `04-azure-validation-cli.png` | VNet, both subnets, tags, and the remote state blob in Azure |
| `05-azure-subscription-inventory.png` | Deployed resources and least-privilege RBAC for both OIDC identities |
| `06-azure-account-backend.png` | Target subscription and the hardened state storage account |
| `07-repo-home.png` | Repository structure and README |
| `08-pr1-checks.png` | Pull request #1, merged after the required Terraform Plan check |
| `09-actions-runs-list.png` | Full workflow run history, including the blocked runs |
