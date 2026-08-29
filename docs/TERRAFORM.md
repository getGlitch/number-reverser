# Terraform

## 1. Purpose

Terraform is responsible for provisioning and managing the AWS infrastructure required by the application.

The infrastructure is designed so that a new environment can be recreated from code rather than manually configured through the AWS console.

---

## 2. Terraform Structure

```text
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── versions.tf
└── ...
```

The main Terraform configuration composes reusable modules rather than defining every AWS resource directly.

---

## 3. Terraform Modules

The environment primarily uses:

```text
terraform-aws-modules/vpc/aws
terraform-aws-modules/eks/aws
terraform-aws-modules/kms/aws
```

The VPC module manages networking.

The EKS module manages:

- EKS cluster
- Managed node groups
- IAM resources
- EKS add-ons
- Access entries
- KMS encryption integration
- OIDC provider

---

## 4. VPC

The VPC contains:

```text
Public Subnets
Private Subnets
NAT Gateway
Internet Gateway
Route Tables
Security Groups
```

The EKS worker nodes use private subnets.

The private subnet route configuration provides outbound internet connectivity through NAT where required.

---

## 5. EKS Configuration

The cluster is configured for Kubernetes `1.33`.

Both EKS API endpoint modes are enabled:

```hcl
endpoint_public_access  = true
endpoint_private_access = true
```

The cluster also enables control-plane logging.

---

## 6. Managed Node Group

The project uses an EKS managed node group.

Current development sizing:

```text
Instance type: t3.small
Desired:       1
Minimum:       1
Maximum:       2
Capacity:      ON_DEMAND
```

This is intentionally conservative for cost control.

---

## 7. EKS Access Entries

EKS access entries are defined through Terraform.

The cluster creator admin permission bootstrap is disabled:

```hcl
enable_cluster_creator_admin_permissions = false
```

Access is explicitly configured using EKS access entries.

The configured principals include:

```text
arn:aws:iam::598907064200:root

arn:aws:iam::598907064200:role/GitHubActions-NumberReverser
```

Both are associated with:

```text
AmazonEKSClusterAdminPolicy
```

with cluster-level scope.

---

## 8. KMS Encryption

The EKS cluster uses KMS encryption for Kubernetes secrets.

```hcl
encryption_config = {
  resources = ["secrets"]
}
```

The EKS module creates and manages the KMS key.

The KMS policy includes:

- Default account-root permissions
- Key administration permissions
- EKS cluster role key usage permissions

The GitHub Actions role is intentionally not used as the KMS encryption key administrator.

---

## 9. EKS Add-ons

The cluster uses the following managed add-ons:

```text
vpc-cni
kube-proxy
coredns
```

The configuration allows the module to select the most recent compatible versions.

`vpc-cni` is configured to be installed before compute resources.

---

## 10. Terraform State

Terraform state is managed deliberately rather than committed to Git.

The state file must never be committed to the repository.

The working state contains infrastructure information required by Terraform to calculate changes.

For a production implementation, the preferred design would be:

```text
Terraform
    |
    v
S3 Remote State
    |
    +--> Versioning
    +--> Encryption
    +--> Restricted IAM access
```

with state locking enabled using the appropriate AWS-supported mechanism.

---

## 11. Terraform Workflow

The standard workflow is:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
```

### Initialize

```bash
cd terraform
terraform init
```

### Format

```bash
terraform fmt -check -recursive
```

### Validate

```bash
terraform validate
```

### Review Changes

```bash
terraform plan
```

### Apply

```bash
terraform apply
```

Terraform apply is intentionally treated as an infrastructure operation requiring review and approval.

The CI pipeline currently performs validation and plan checks; application deployment is handled separately through Kubernetes.

---

## 12. Security Scanning

Checkov scans the Terraform configuration:

```bash
checkov \
  -d . \
  --framework terraform \
  --download-external-modules true
```

The purpose is to identify insecure infrastructure configuration before infrastructure changes are accepted.

---

## 13. Destroy

The complete environment can be removed using:

```bash
cd terraform
terraform destroy
```

The destroy operation should be reviewed carefully because it removes the provisioned AWS infrastructure.
