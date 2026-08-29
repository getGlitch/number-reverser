# Architecture

## 1. Overview

The project uses Amazon EKS as the Kubernetes platform and Terraform as the infrastructure provisioning layer.

The architecture intentionally keeps worker nodes in private subnets while exposing only the required application entry points.

---

## 2. High-Level Architecture

```text
                         Internet
                            |
                            |
                     GitHub / Developer
                            |
                            v
                    GitHub Actions
                            |
                +-----------+-----------+
                |                       |
                v                       v
        GitHub Container         AWS via OIDC
           Registry                  |
                |                     |
                |                     v
                |                 AWS IAM
                |                     |
                |                     v
                |                  EKS API
                |                     |
                +----------+----------+
                           |
                           v
                    Amazon EKS Cluster
                           |
              +------------+------------+
              |                         |
              v                         v
       Kubernetes API             Worker Nodes
                                    Private Subnets
                                         |
                                    +----+----+
                                    |         |
                                    v         v
                               Application  Add-ons
                                  Pods
                                    |
                                    v
                              Kubernetes Service
```

---

## 3. AWS Network Architecture

The VPC contains separate public and private subnets.

```text
                         AWS Region
                        ap-south-1
                            |
                           VPC
                            |
             +--------------+--------------+
             |                             |
       Public Subnets                 Private Subnets
             |                             |
       NAT Gateway                  EKS Worker Nodes
             |                             |
             |                       Application Pods
             |
       Internet Gateway
```

The EKS worker nodes are placed in private subnets.

This prevents worker nodes from requiring direct public internet exposure.

Private subnet workloads use NAT for outbound connectivity where required.

---

## 4. EKS

The cluster configuration is:

| Property | Value |
|---|---|
| Cluster | `number-reverser` |
| Region | `ap-south-1` |
| Kubernetes | `1.33` |
| Compute | EKS Managed Node Group |
| Node Instance | `t3.small` |
| Desired Nodes | `1` |
| Minimum Nodes | `1` |
| Maximum Nodes | `2` |

The current sizing is intentionally small to control development cost.

---

## 5. EKS Access

EKS access is configured using EKS access entries rather than relying on manually maintained `aws-auth` configuration.

Two identities are explicitly configured:

```text
AWS Account Root
       |
       +--> EKS Cluster Admin Access

GitHubActions-NumberReverser Role
       |
       +--> EKS Cluster Admin Access
```

The GitHub Actions role is the identity used by the deployment workflow.

---

## 6. Encryption

Kubernetes secrets are encrypted using AWS KMS through the EKS encryption configuration.

```text
Kubernetes Secret
       |
       v
EKS Encryption Configuration
       |
       v
AWS KMS Key
       |
       v
Encrypted Secret Storage
```

The KMS key is created and managed through the Terraform EKS module.

---

## 7. Logging

EKS control-plane logging is enabled for:

```text
API
Audit
Authenticator
Controller Manager
Scheduler
```

CloudWatch log retention is configured for 365 days.

---

## 8. Application Architecture

The application is packaged as a Docker image and deployed to EKS.

```text
GitHub Repository
       |
       v
Docker Build
       |
       v
GHCR
       |
       v
EKS Deployment
       |
       v
Application Pod
       |
       v
Kubernetes Service
```

The image is identified using the Git commit SHA rather than the mutable `latest` tag.

Example:

```text
ghcr.io/<owner>/number-reverser:<git-sha>
```

This provides traceability between:

```text
Git commit
    ↓
Container image
    ↓
Kubernetes deployment
```

---

## 9. Network Segmentation

A Kubernetes NetworkPolicy restricts pod-to-pod communication.

The policy is designed around required application communication rather than allowing unrestricted pod networking.

This provides a second layer of network isolation inside the VPC:

```text
AWS Security Groups
        +
Kubernetes NetworkPolicy
        =
Layered Network Controls
```

---

## 10. Design Trade-offs

### Single managed node group

A single small node group keeps the environment inexpensive and simple for a take-home exercise.

For production, node capacity would normally be distributed across multiple Availability Zones with appropriate capacity and disruption planning.

### Public EKS endpoint

The EKS API endpoint is currently configured with public access to simplify CI/CD connectivity.

Private access is also enabled.

For a regulated production environment, access to the Kubernetes API would normally be restricted further through network controls or a private access architecture.

### Small node size

`t3.small` is sufficient for this workload and keeps the development environment cost-conscious.

Production sizing would be based on measured workload requirements.

---

## 11. Primary Design Principles

The architecture follows four primary principles:

1. Infrastructure is reproducible through Terraform.
2. Worker nodes are not directly exposed to the internet.
3. CI/CD authenticates to AWS using OIDC rather than static credentials.
4. Kubernetes admission and network controls provide defense in depth.
