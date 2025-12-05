# Infrastructure (Infrastructure-as-Code) for Sci Discovery Agent

This document describes the Infrastructure-as-Code (IaC) used to provision the cloud resources for the Sci Discovery Agent — an agentic research/discovery system. It explains repository layout, Terraform usage, common commands for PowerShell (Windows), variables/secrets, and recommended next steps (state locking, CI/CD, backup).

**Goals:**
- Provide reproducible infrastructure for running the agent and research workloads.
- Keep configuration parametrized and environment-specific via `terraform.tfvars`.
- Make deployments repeatable and auditable using Terraform.

**Providers & Region**
- Primary cloud provider: AWS (current example/intent uses `us-east-1`).

**What’s Included**
- `infra/terraform/` - Terraform configuration for compute, networking, and persistent services.
- `infra/terraform/terraform.tfvars.example` - Example variables file. Copy to `terraform.tfvars` and edit per environment.
- `configs/` - YAML configs for experiments and agent settings (e.g., `btc_1h_baseline.yaml`).
- `db/schema_v1.sql` and `db/connection.py` - Database schema and connection helper.
- `scripts/` - Utility scripts (ingest, run experiments, infra helpers). Example: `scripts/apply_infra.sh`.

Repository layout (relevant files/folders):

```
./
  infra.md                    # (this file) IaC README and notes
  infra/terraform/            # Terraform code for provisioning
    main.tf
    variables.tf
    outputs.tf
    terraform.tfvars.example
    terraform.tfstate         # (local state; consider remote state)
  configs/                    # runtime/experiment configuration
  db/                         # DB schema and helpers
  scripts/                    # helper scripts (ingest, run, apply infra)
```

Getting started (prerequisites)
- Install Terraform (tested on Terraform 1.5+). Verify with:

```powershell
terraform -v
```

- Configure AWS credentials (recommended: use an IAM user or role with limited permissions):

```powershell
# Using environment variables in PowerShell
$Env:AWS_ACCESS_KEY_ID = "<your-access-key>";
$Env:AWS_SECRET_ACCESS_KEY = "<your-secret-key>";
$Env:AWS_DEFAULT_REGION = "us-east-1";
```

- Install AWS CLI (optional) and authenticate if you use profile-based creds:

```powershell
aws configure --profile myprofile
```

Recommended workflow (Terraform, PowerShell)

1) Initialize the Terraform working directory:

```powershell
cd infra/terraform
terraform init
```

2) Create or copy a variables file from the example and edit values:

```powershell
cp .\terraform.tfvars.example .\terraform.tfvars
# then edit .\terraform.tfvars in your editor
```

3) Review the plan:

```powershell
terraform plan -var-file="terraform.tfvars"
```

4) Apply the plan to create resources:

```powershell
terraform apply -var-file="terraform.tfvars"
```

5) After deploy
- Note any outputs (public IPs, RDS endpoints, S3 bucket names) and update local application config or secrets store as needed.

Important variables and secrets
- `terraform.tfvars` contains sensitive values (DB passwords, SSH key names, bucket suffixes). Do NOT commit real secrets to git. Use environment variables, encrypted secret stores, or remote state with encryption.
- SSH key: the repo currently references an SSH key name like `sci-agent-key.pem`. Ensure the private key is securely stored (e.g., `~/.ssh/sci-agent-key.pem`) and its public key is used in the Terraform `aws_key_pair` resource or through an existing key name.

State management & locking (recommended)
- The repo currently contains local state files in `infra/terraform/`. For team usage and safety, move to remote state:
  - Backend: `S3` with `DynamoDB` state locking (recommended for Terraform on AWS).
  - Configure a backend in `infra/terraform/backend.tf` and migrate state with `terraform init -migrate-state`.

Security & networking notes
- Security Groups should be restrictive: open only required ports (SSH locked to operator IP or session manager, application ports behind load balancer, DB accessible only from app subnets).
- Use IAM roles for EC2 to grant least-privilege access (S3, Secrets Manager, SSM).

Typical resources created (examples)
- EC2 instances for agent runtime and research workloads (here: `sci-agent-app`, `sci-agent-research`).
- RDS PostgreSQL instance (example: `db.t3.medium`), with secure username/password stored outside source control.
- S3 bucket (e.g., `sci-discovery-data-<handle>`) for experiment artifacts, snapshots, and backups.

Common maintenance tasks
- Inspect current Terraform-managed resources:

```powershell
cd infra/terraform
terraform show
```

- Update resources: modify Terraform config, `terraform plan`, then `terraform apply`.
- Tear down infrastructure (when safe):

```powershell
cd infra/terraform
terraform destroy -var-file="terraform.tfvars"
```

Backups & DR
- Backup DB regularly (automated snapshots or managed backups via RDS).
- Configure S3 lifecycle or versioning for important buckets.

CI/CD and automation recommendations
- Add a pipeline (GitHub Actions / GitLab CI / other) that:
  - Validates Terraform with `terraform fmt` and `terraform validate`.
  - Runs `terraform plan` on PRs and `terraform apply` from protected branches.
  - Uses stored secrets and remote state backend to avoid leaking credentials.

Operational next steps
- Move Terraform state to a remote backend (S3 + DynamoDB locking).
- Add automated backups for RDS and document recovery procedures.
- Add CloudWatch alarms, log aggregation, and a basic runbook for common failures.

Notes & TODOs
- Current local state files exist in `infra/terraform/terraform.tfstate`. Do not commit sensitive state into version control. Migrate to remote state and remove local state from the repo.
- Consider using `aws_ssm` or Secrets Manager for DB credentials instead of storing them in TF variables.

Contact / Author
- Maintainer: repository owner (Shrey).

If you’d like, I can:
- Convert Terraform state to an S3 backend and add a `backend.tf` template.
- Add a GitHub Actions workflow for plan/apply with secure secrets.
- Generate an example `terraform.tfvars` from current environment values.

---
Generated: December 2025 — tailored to this repository. Update any region/instance sizes to match your needs.
