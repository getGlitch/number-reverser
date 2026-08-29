
---

# 3. `docs/TERRAFORM.md`

```markdown
# Terraform and Infrastructure

## Objective

Terraform is the source of truth for the AWS infrastructure and supporting Kubernetes platform components.

The configuration avoids manually creating AWS resources through the console.

## Module Structure

The project uses established Terraform modules for major infrastructure components.

The EKS module is:

```text
terraform-aws-modules/eks/aws



Version:

~> 21.0

The VPC is also managed using the Terraform AWS VPC module.

This keeps the root configuration focused on environment-specific decisions rather than reimplementing AWS networking primitives.

AWS Resources

The Terraform configuration manages:

VPC
Public subnets
Private subnets
Internet Gateway
NAT Gateway
Route tables
Security groups
EKS cluster
Managed node group
EKS addons
IAM roles and policy attachments
EKS OIDC provider
KMS encryption
CloudWatch log configuration
EKS access entries
VPC Design

The VPC separates public and private networking.

Public resources provide internet-facing connectivity where required.

Worker nodes are placed in private subnets.

The private route tables use the NAT Gateway for outbound internet access.

This allows nodes to retrieve required external resources without assigning public IP addresses directly to the worker nodes.

EKS Configuration

The cluster configuration includes:

kubernetes_version = "1.33"

endpoint_public_access  = true
endpoint_private_access = true

The EKS addons include:

VPC CNI
kube-proxy
CoreDNS
Node Group

The development node group is intentionally small:

Instance type: t3.small
Desired: 1
Minimum: 1
Maximum: 2

The nodes use private subnets.

The node group uses ON_DEMAND capacity.

Terraform State

Terraform state is stored remotely in S3.

The backend configuration uses:

Bucket: number-reverser-tfstate-...
Region: ap-south-1
Encryption: enabled
Locking: S3 lockfile

The state is therefore not dependent on a local workstation state file.

This also allows CI/CD and other authorized operators to work against the same state.

Authentication

GitHub Actions authenticates to AWS using OIDC.

The workflow assumes:

GitHubActions-NumberReverser

This avoids storing long-lived AWS access keys in GitHub repository secrets.

The workflow requests:

id-token: write

and the AWS credentials action exchanges the GitHub OIDC identity for temporary AWS credentials.

EKS Access Entries

The EKS cluster uses EKS access entries.

The configured GitHub Actions role receives the EKS cluster administrator access policy required by this project.

The cluster creator access configuration was also explicitly managed rather than relying on the implicit cluster-creator bootstrap permission.

KMS Encryption

EKS secrets encryption is enabled:

encryption_config = {
  resources = ["secrets"]
}

The EKS module creates and manages a KMS key for this encryption configuration.

The KMS policy grants key usage to the EKS cluster role as required by the module.

Terraform Validation

Before infrastructure changes are accepted, the pipeline performs:

terraform fmt -check -recursive
terraform validate
terraform plan

The pipeline also runs Checkov against the Terraform configuration.

Plan vs Apply

The CI pipeline currently uses Terraform for validation and planning.

Infrastructure creation or modification is intentionally treated as a controlled infrastructure operation rather than automatically applying every pull request.

The important workflow is:

terraform fmt
      |
terraform validate
      |
Checkov
      |
terraform plan
      |
review
      |
controlled terraform apply

For a larger production environment, I would introduce a dedicated protected apply stage with environment approval and a saved Terraform plan artifact.

Drift Detection

Terraform plan compares the declared configuration with the current state and infrastructure.

If infrastructure changes outside Terraform, the next plan can report the detected difference.

This provides a mechanism to identify configuration drift rather than silently accepting manual changes.

Teardown

The environment can be removed using:

cd terraform
terraform destroy

Before running destroy, review the proposed resources carefully because this removes the infrastructure managed by the Terraform state.
