
---

# 2. `docs/ARCHITECTURE.md`

```markdown
# Architecture

## Overview

The Number Reverser is deployed as a containerized workload on Amazon EKS.

Infrastructure is provisioned using Terraform and the application is deployed through GitHub Actions using Kubernetes manifests managed with Kustomize.

The design separates:

1. AWS infrastructure
2. Kubernetes platform
3. Application workload
4. CI/CD
5. Security controls

## High-Level Architecture

```text
                           Internet
                              |
                              |
                       AWS VPC / Public
                              |
                    +---------+---------+
                    |                   |
             Internet Gateway       NAT Gateway
                                        |
                                        v
                              Private Subnets
                                        |
                              +---------+---------+
                              |                   |
                         EKS Control Plane    EKS Nodes
                                                  |
                                           +------+------+
                                           |             |
                                      Kyverno       Application
                                      Policies          Pods
                                                         |
                                                  NetworkPolicy
                                                         |
                                                       Service


AWS Layer

Terraform creates the AWS networking and EKS resources.

The VPC contains public and private subnets.

The worker nodes are placed in private subnets rather than directly exposing the nodes to the internet.

The private subnet routing uses NAT for outbound connectivity where required.

EKS Layer

The cluster is:

Cluster: number-reverser
Region: ap-south-1
Kubernetes: 1.33

A managed node group is used for worker capacity.

Current development sizing:

Instance type: t3.small
Desired: 1
Minimum: 1
Maximum: 2
Capacity: ON_DEMAND

This sizing was selected to keep the development environment small while still allowing basic node scaling.

Kubernetes Layer

The application is deployed into:

number-reverser-dev

Kustomize is used to maintain the Kubernetes configuration and update the application image for each deployment.

The deployment process updates the image to the Git commit SHA:

ghcr.io/<owner>/number-reverser:<git-sha>

This avoids using a mutable latest deployment tag.

Security Boundaries

There are multiple security boundaries:

AWS IAM

GitHub Actions does not use a long-lived AWS access key.

The workflow authenticates through GitHub's OIDC integration and assumes the configured AWS IAM role.

EKS Access

EKS access is managed through EKS access entries rather than relying on manually maintained cluster authentication configuration.

Network

Worker nodes run in private subnets.

Kubernetes NetworkPolicy provides workload-level traffic restrictions.

Kubernetes Admission

Kyverno runs as an admission controller and enforces workload security requirements before workloads are accepted by the cluster.

Container

The application image uses a slim Python base image and creates a dedicated non-root user.

Logging

EKS control-plane log types enabled by Terraform include:

API
Audit
Authenticator
Controller Manager
Scheduler

The configured CloudWatch retention is 365 days for this environment.

Design Trade-offs
One EKS Node

The development environment uses one desired node to control cost.

The node group allows scaling up to two nodes.

This is appropriate for the take-home environment but is not equivalent to a production multi-AZ node strategy.

Public EKS API Endpoint

The EKS API endpoint currently has public access enabled as well as private access.

This simplifies administration from the GitHub Actions runner and development environment.

For a regulated production environment, I would further restrict the public endpoint using an allowlist or move administration toward private connectivity.

NAT Gateway

A NAT Gateway provides outbound internet connectivity for resources in private subnets.

For a production multi-AZ architecture, NAT would normally be designed per availability zone to avoid a single-AZ dependency.

Data Flow
Developer pushes code to GitHub.
GitHub Actions runs tests and security checks.
Docker builds the application image.
Trivy scans the image.
Syft generates the SBOM.
The image is pushed to GHCR.
Cosign creates a keyless signature.
Cosign verifies the signature.
GitHub Actions authenticates to AWS using OIDC.
Kubernetes credentials are configured for EKS.
Kustomize updates the image reference.
Kubernetes applies the manifests.
The deployment rollout is monitored.
AWS Layer

Terraform creates the AWS networking and EKS resources.

The VPC contains public and private subnets.

The worker nodes are placed in private subnets rather than directly exposing the nodes to the internet.

The private subnet routing uses NAT for outbound connectivity where required.

EKS Layer

The cluster is:

Cluster: number-reverser
Region: ap-south-1
Kubernetes: 1.33

A managed node group is used for worker capacity.

Current development sizing:

Instance type: t3.small
Desired: 1
Minimum: 1
Maximum: 2
Capacity: ON_DEMAND

This sizing was selected to keep the development environment small while still allowing basic node scaling.

Kubernetes Layer

The application is deployed into:

number-reverser-dev

Kustomize is used to maintain the Kubernetes configuration and update the application image for each deployment.

The deployment process updates the image to the Git commit SHA:

ghcr.io/<owner>/number-reverser:<git-sha>

This avoids using a mutable latest deployment tag.

Security Boundaries

There are multiple security boundaries:

AWS IAM

GitHub Actions does not use a long-lived AWS access key.

The workflow authenticates through GitHub's OIDC integration and assumes the configured AWS IAM role.

EKS Access

EKS access is managed through EKS access entries rather than relying on manually maintained cluster authentication configuration.

Network

Worker nodes run in private subnets.

Kubernetes NetworkPolicy provides workload-level traffic restrictions.

Kubernetes Admission

Kyverno runs as an admission controller and enforces workload security requirements before workloads are accepted by the cluster.

Container

The application image uses a slim Python base image and creates a dedicated non-root user.

Logging

EKS control-plane log types enabled by Terraform include:

API
Audit
Authenticator
Controller Manager
Scheduler

The configured CloudWatch retention is 365 days for this environment.

Design Trade-offs
One EKS Node

The development environment uses one desired node to control cost.

The node group allows scaling up to two nodes.

This is appropriate for the take-home environment but is not equivalent to a production multi-AZ node strategy.

Public EKS API Endpoint

The EKS API endpoint currently has public access enabled as well as private access.

This simplifies administration from the GitHub Actions runner and development environment.

For a regulated production environment, I would further restrict the public endpoint using an allowlist or move administration toward private connectivity.

NAT Gateway

A NAT Gateway provides outbound internet connectivity for resources in private subnets.

For a production multi-AZ architecture, NAT would normally be designed per availability zone to avoid a single-AZ dependency.

Data Flow
Developer pushes code to GitHub.
GitHub Actions runs tests and security checks.
Docker builds the application image.
Trivy scans the image.
Syft generates the SBOM.
The image is pushed to GHCR.
Cosign creates a keyless signature.
Cosign verifies the signature.
GitHub Actions authenticates to AWS using OIDC.
Kubernetes credentials are configured for EKS.
Kustomize updates the image reference.
Kubernetes applies the manifests.
The deployment rollout is monitored.
