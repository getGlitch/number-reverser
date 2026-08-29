
---

# 7. `docs/DEPLOYMENT.md`

```markdown
# Deployment

## Prerequisites

The following tools are required for local infrastructure operations:

- AWS CLI
- Terraform
- kubectl
- Docker
- Git

The GitHub Actions pipeline provides the automated CI/CD path.

## AWS Authentication

AWS credentials must have the permissions required to provision the Terraform-managed resources.

For CI/CD, GitHub Actions uses OIDC and assumes the configured IAM role.

Do not commit AWS access keys to the repository.

## Terraform Initialization

Change into the Terraform directory:

```bash
cd terraform


Initialize Terraform:

terraform init
Validate Configuration

Run:

terraform fmt -check -recursive
terraform validate
Review Infrastructure Changes

Run:

terraform plan

Always review the plan before applying infrastructure changes.

Apply Infrastructure

For controlled infrastructure provisioning:

terraform apply

Review the proposed resources and explicitly approve the operation.

Verify EKS

Configure kubectl:

aws eks update-kubeconfig \
  --name number-reverser \
  --region ap-south-1

Verify access:

kubectl get nodes
Application Deployment

The normal application deployment path is GitHub Actions.

A push to main causes the pipeline to:

Build the image.
Scan the image.
Generate the SBOM.
Push the image to GHCR.
Sign the image.
Verify the signature.
Update the Kustomize image.
Apply the Kubernetes manifests.
Wait for the rollout.
Verify Kubernetes resources.
Verify Application

Check the namespace:

kubectl get all -n number-reverser-dev

Check pods:

kubectl get pods -n number-reverser-dev

Check deployment:

kubectl get deployment \
  number-reverser \
  -n number-reverser-dev

Check service:

kubectl get svc -n number-reverser-dev
Rollout Verification
kubectl rollout status \
  deployment/number-reverser \
  -n number-reverser-dev \
  --timeout=180s
Inspect Image
kubectl get deployment \
  number-reverser \
  -n number-reverser-dev \
  -o jsonpath='{.spec.template.spec.containers[*].image}'

The expected image should contain the Git commit SHA rather than latest.

Inspect Kyverno
kubectl get pods -n kyverno

Check the installed release:

helm list -n kyverno
Teardown

When the environment is no longer required:

cd terraform
terraform plan -destroy

Review the destroy plan.

Then:

terraform destroy

Confirm the operation only after reviewing the resources scheduled for deletion.

Cost Control

This project is intentionally sized as a development environment.

Before finishing the review period, destroy unused AWS resources to avoid unnecessary cloud charges.

