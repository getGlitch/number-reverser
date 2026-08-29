# Number Reverser

A small Python HTTP service deployed to Amazon EKS with Terraform-managed infrastructure and a security-gated GitHub Actions CI/CD pipeline.

The application is intentionally simple. The focus of this project is the engineering around it:

- Infrastructure as Code
- Kubernetes deployment
- Container security
- IaC security scanning
- Vulnerability scanning
- SBOM generation
- Keyless container signing
- Kubernetes admission policies
- Network isolation
- AWS IAM/OIDC integration
- Automated deployment

## Architecture

```text
                         GitHub
                           |
                           v
                  GitHub Actions
                           |
        +------------------+------------------+
        |                  |                  |
        v                  v                  v
   Unit Tests          Checkov             Docker
        |             Terraform             Build
        |                  |                  |
        +------------------+------------------+
                           |
                           v
                       Trivy
                    CRITICAL gate
                           |
                           v
                         Syft
                         SBOM
                           |
                           v
                       GHCR Push
                           |
                           v
                      Cosign Sign
                           |
                           v
                    Cosign Verify
                           |
                           v
                     AWS OIDC
                           |
                           v
                         EKS
                           |
                           v
                    Kustomize Deploy
                           |
                           v
                 Number Reverser Pods
                           |
                           v
                       Service


AWS Infrastructure

Terraform provisions:

VPC
Public and private subnets
Internet Gateway
NAT Gateway
Route tables
Security groups
Amazon EKS cluster
Managed node group
EKS addons
KMS key for Kubernetes secret encryption
CloudWatch log configuration
EKS access entries
IAM/OIDC integration

The EKS worker nodes are deployed into private subnets.

The current development environment uses:

AWS Region: ap-south-1
EKS cluster: number-reverser
Kubernetes: 1.33
Node instance type: t3.small
Node group desired size: 1
Node group min/max: 1/2
Application

The service accepts a number and returns its reversed representation.

Example:

12345 -> 54321

The application also handles the required edge cases, including negative numbers, zeros, invalid input and integer-size considerations according to the behavior documented in the application tests.

CI/CD

The pipeline is intentionally separated into logical stages:


Lint & Unit Tests
        |
        v
Terraform Security Scan
        |
        v
Container Build & Security
        |
        v
Terraform Plan
        |
        v
Image Push & Signing
        |
        v
EKS Deployment
        |
        v
Rollout Verification


Pull requests execute validation and security checks without deploying.

A push to main continues through image publishing, signing and deployment.

Security Controls

Implemented security controls include:

Checkov Terraform scanning
Trivy container vulnerability scanning
Critical vulnerability pipeline gate
Syft CycloneDX SBOM
SBOM uploaded as a GitHub Actions artifact
Cosign keyless/OIDC image signing
Cosign signature verification
GitHub Actions OIDC authentication to AWS
EKS access entries
KMS encryption for Kubernetes secrets
Kubernetes admission control with Kyverno
Kubernetes NetworkPolicy
Non-root application container
Versioned image tags using Git commit SHA
No long-lived AWS credentials stored in GitHub

See SECURITY.md for the implemented controls and their locations.

Documentation
Document	Purpose
Architecture	AWS, EKS and application architecture
Terraform	Infrastructure and state management
CI/CD	Pipeline stages and security gates
Kubernetes	Kubernetes deployment and policies
Security	Implemented security controls
Deployment	Deployment and teardown procedures
Troubleshooting	Problems encountered and resolutions
Repository Structure
.
├── app/
│   ├── application code
│   ├── requirements.txt
│   └── tests
│
├── terraform/
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── k8s/
│   ├── base/
│   └── overlays/
│       └── dev/
│
├── docs/
│   ├── ARCHITECTURE.md
│   ├── TERRAFORM.md
│   ├── CI-CD.md
│   ├── KUBERNETES.md
│   ├── DEPLOYMENT.md
│   └── TROUBLESHOOTING.md
│
├── SECURITY.md
├── Dockerfile
├── .dockerignore
└── .github/
    └── workflows/
        └── ci-cd.yml
Teardown

The infrastructure is Terraform-managed and can be removed with:

cd terraform
terraform destroy

Always verify the resources that will be removed before confirming the destroy operation.

Project Objective

The goal was not to build a complex application.

The objective was to demonstrate how a small service can be treated as a production-style workload:

code -> test -> scan -> package -> attest -> deploy -> verify
