# Deployment Guide

## 1. Prerequisites

The following tools are required for local infrastructure operations:

- AWS CLI
- Terraform
- kubectl
- Git
- Docker

AWS credentials must have permission to provision the required infrastructure.

For CI/CD, GitHub Actions uses AWS OIDC rather than static AWS access keys.

---

# 2. Infrastructure Deployment

Move into the Terraform directory:

```bash
cd terraform
```

Initialize Terraform:

```bash
terraform init
```

Format and validate:

```bash
terraform fmt -check -recursive
terraform validate
```

Review the proposed infrastructure:

```bash
terraform plan
```

Apply the infrastructure:

```bash
terraform apply
```

Review the plan carefully before approving the apply operation.

---

# 3. Verify AWS Resources

Verify the AWS identity:

```bash
aws sts get-caller-identity
```

Verify the EKS cluster:

```bash
aws eks describe-cluster \
  --name number-reverser \
  --region ap-south-1
```

---

# 4. Configure kubectl

Update the local kubeconfig:

```bash
aws eks update-kubeconfig \
  --name number-reverser \
  --region ap-south-1
```

Verify cluster access:

```bash
kubectl get nodes
```

---

# 5. Verify Kubernetes Resources

Check the application namespace:

```bash
kubectl get namespace number-reverser-dev
```

Check the Deployment:

```bash
kubectl get deployment \
  -n number-reverser-dev
```

Check Pods:

```bash
kubectl get pods \
  -n number-reverser-dev
```

Check the Service:

```bash
kubectl get svc \
  -n number-reverser-dev
```

---

# 6. Application Deployment

The GitHub Actions pipeline handles application deployment to EKS.

The deployment process is:

```text
Build image
    ↓
Security scan
    ↓
Generate SBOM
    ↓
Push image
    ↓
Sign image
    ↓
Verify signature
    ↓
Update Kustomize image
    ↓
kubectl apply -k
    ↓
Wait for rollout
```

The image is identified using the Git commit SHA.

Example:

```text
ghcr.io/<owner>/number-reverser:<git-sha>
```

---

# 7. Manual Kubernetes Deployment

For troubleshooting or controlled local testing:

```bash
kubectl apply -k k8s/overlays/dev
```

Verify the rollout:

```bash
kubectl rollout status \
  deployment/number-reverser \
  -n number-reverser-dev \
  --timeout=180s
```

---

# 8. Verify the Application

Inspect the running Pods:

```bash
kubectl get pods \
  -n number-reverser-dev \
  -o wide
```

Inspect the Deployment:

```bash
kubectl describe deployment \
  number-reverser \
  -n number-reverser-dev
```

Inspect application logs:

```bash
kubectl logs \
  deployment/number-reverser \
  -n number-reverser-dev
```

---

# 9. Teardown

When the environment is no longer required, destroy the AWS infrastructure:

```bash
cd terraform
terraform destroy
```

Review the resources carefully before confirming.

The purpose of teardown is to prevent unnecessary cloud charges after the evaluation.

---

# 10. Deployment Separation

The project intentionally separates infrastructure and application deployment.

### Terraform

Manages:

```text
VPC
EKS
IAM
KMS
Node Groups
AWS Add-ons
```

### Kubernetes/Kustomize

Manages:

```text
Namespace
Deployment
Service
NetworkPolicy
Application configuration
```

This prevents application releases from requiring unnecessary recreation or modification of AWS infrastructure.
