# Number Reverser

A small containerized HTTP service deployed to Amazon EKS using Terraform, Kubernetes, GitHub Actions, and security-focused CI/CD controls.

The application itself is intentionally simple. The primary focus of this project is the engineering around it:

- Infrastructure as Code
- Secure AWS authentication from GitHub Actions
- Kubernetes deployment
- Infrastructure and container security scanning
- SBOM generation
- Container image signing and verification
- Kubernetes admission policy enforcement
- Network segmentation
- Reproducible deployments

---

## Project Overview

```text
Developer
   |
   | Git push / Pull Request
   v
GitHub
   |
   v
GitHub Actions
   |
   +--> Lint
   +--> Unit Tests
   +--> Terraform Validation
   +--> Checkov
   +--> Docker Build
   +--> Trivy
   +--> Syft SBOM
   +--> Cosign Signing
   |
   v
GitHub Container Registry
   |
   v
Amazon EKS
   |
   +--> Kyverno admission policies
   +--> NetworkPolicy
   +--> Kubernetes Deployment
   +--> Service
```

---

## Technology Stack

| Area | Technology |
|---|---|
| Application | Python |
| Container | Docker |
| Cloud | AWS |
| Kubernetes | Amazon EKS |
| Infrastructure | Terraform |
| CI/CD | GitHub Actions |
| Container Registry | GitHub Container Registry |
| IaC Security | Checkov |
| Image Security | Trivy |
| SBOM | Syft |
| Image Signing | Cosign |
| Policy Enforcement | Kyverno |
| Network Security | Kubernetes NetworkPolicy |
| Configuration | Kustomize |

---

## Application

The service reverses numeric input.

Example:

```text
12345 → 54321
```

The implementation also handles the required edge cases:

- Negative numbers
- Leading/trailing zeros
- Non-numeric input
- Integer overflow

The application has unit tests covering the expected behavior.

---

## Infrastructure

AWS infrastructure is provisioned entirely through Terraform.

The environment includes:

- VPC
- Public and private subnets
- NAT gateway
- Amazon EKS cluster
- Managed node group
- IAM roles and policies
- EKS access entries
- KMS encryption for Kubernetes secrets
- CloudWatch logging
- EKS managed add-ons

Worker nodes run in private subnets rather than being directly exposed to the internet.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the complete architecture.

See [`docs/TERRAFORM.md`](docs/TERRAFORM.md) for the Terraform implementation.

---

## CI/CD

The GitHub Actions pipeline validates the application and infrastructure before deployment.

The main flow is:

```text
Lint
  ↓
Unit Tests
  ↓
Terraform Validation + Checkov
  ↓
Docker Build
  ↓
Trivy Image Scan
  ↓
SBOM Generation
  ↓
Push Image
  ↓
Cosign Sign
  ↓
Cosign Verify
  ↓
Deploy to EKS
  ↓
Rollout Verification
```

Critical container vulnerabilities fail the pipeline.

The container image is signed using Cosign with GitHub Actions OIDC and the signature is verified before deployment.

See [`docs/CI-CD.md`](docs/CI-CD.md).

---

## Kubernetes Security

The workload is deployed into a dedicated namespace:

```text
number-reverser-dev
```

The deployment uses:

- Kubernetes Deployment
- Kubernetes Service
- Kustomize
- NetworkPolicy
- Kyverno admission policies
- Non-`:latest` image references
- Resource requests and limits
- Restricted workload configuration

Kyverno is used to enforce workload security requirements at admission time.

See [`docs/KUBERNETES.md`](docs/KUBERNETES.md).

---

## Security

Security controls are implemented at multiple layers:

```text
Source
  ↓
Checkov
  ↓
Container
  ↓
Trivy
  ↓
SBOM
  ↓
Cosign
  ↓
Kubernetes
  ↓
Kyverno
  ↓
NetworkPolicy
```

No long-lived AWS access keys are stored in GitHub Actions.

GitHub Actions assumes the AWS deployment role using GitHub OIDC.

See [`SECURITY.md`](SECURITY.md) for the implemented security controls and evidence.

---

## Deployment

Infrastructure and application deployment are intentionally separated.

Terraform manages the AWS infrastructure.

Kubernetes/Kustomize manages the application workload.

For deployment, verification, and teardown instructions see:

[`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)

---

## Repository Documentation

| Document | Purpose |
|---|---|
| [`ARCHITECTURE.md`](docs/ARCHITECTURE.md) | AWS, EKS, networking and application architecture |
| [`TERRAFORM.md`](docs/TERRAFORM.md) | Terraform structure, state, IAM, EKS, VPC and KMS |
| [`CI-CD.md`](docs/CI-CD.md) | Pipeline stages, security gates and deployment flow |
| [`KUBERNETES.md`](docs/KUBERNETES.md) | Kubernetes workload, Kustomize, Kyverno and NetworkPolicy |
| [`SECURITY.md`](SECURITY.md) | Security controls actually implemented |
| [`DEPLOYMENT.md`](docs/DEPLOYMENT.md) | Deploy, verify and destroy procedures |
| [`TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Issues encountered and their resolutions |

---

## Cost and Teardown

This project was designed around AWS free-tier/trial constraints.

The environment should be destroyed when it is no longer required.

```bash
cd terraform
terraform destroy
```

Always review the Terraform plan before applying infrastructure changes.
