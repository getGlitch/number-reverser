# Security

## Security Scope

This document records the security controls that are actually implemented in this project.

The objective is to demonstrate enforcement rather than simply listing security tools.

---

# 1. Security Controls Summary

| Control | Tool / Mechanism | Implemented |
|---|---|---:|
| IaC security scanning | Checkov | Yes |
| Container vulnerability scanning | Trivy | Yes |
| Critical vulnerability pipeline gate | Trivy | Yes |
| SBOM generation | Syft | Yes |
| SBOM artifact publication | GitHub Actions Artifact | Yes |
| Image signing | Cosign | Yes |
| Image signature verification | Cosign | Yes |
| AWS authentication | GitHub OIDC | Yes |
| Kubernetes admission policy | Kyverno | Yes |
| Privileged workload prevention | Kyverno | Yes |
| Resource limit enforcement | Kyverno | Yes |
| `:latest` image prevention | Kyverno | Yes |
| Kubernetes network segmentation | NetworkPolicy | Yes |
| EKS secrets encryption | AWS KMS | Yes |
| EKS control-plane audit logging | CloudWatch | Yes |
| Static AWS access keys in CI | Not used | Yes |

---

# 2. Infrastructure Security

## Terraform Security Scanning

Checkov scans the Terraform configuration before infrastructure changes are accepted.

Command:

```bash
checkov \
  -d . \
  --framework terraform \
  --download-external-modules true
```

This provides an automated IaC security check for AWS infrastructure configuration.

---

# 3. AWS Authentication

GitHub Actions does not use long-lived AWS access keys.

Authentication uses GitHub OIDC:

```text
GitHub Actions
      |
      | OIDC
      v
AWS IAM Role
      |
      v
AWS APIs
```

The workflow explicitly requests:

```yaml
permissions:
  id-token: write
  contents: read
```

The deployment role is:

```text
GitHubActions-NumberReverser
```

This removes the need to store an AWS access key and secret key in the repository.

---

# 4. EKS Access Control

EKS access is configured using EKS access entries.

The GitHub Actions IAM role is explicitly granted EKS access through:

```text
AmazonEKSClusterAdminPolicy
```

with cluster-level scope.

The cluster creator bootstrap admin permission is explicitly disabled:

```hcl
enable_cluster_creator_admin_permissions = false
```

This keeps the cluster access configuration visible and managed through Terraform.

---

# 5. Container Vulnerability Scanning

Trivy scans the built Docker image.

The pipeline gates on Critical vulnerabilities:

```bash
trivy image \
  --severity CRITICAL \
  --exit-code 1 \
  number-reverser:<git-sha>
```

The important control is:

```text
CRITICAL vulnerability
        ↓
Exit code 1
        ↓
Pipeline failure
        ↓
No deployment
```

Therefore the scan is an enforced release gate.

---

# 6. SBOM

Syft generates a CycloneDX JSON SBOM from the built container image.

```bash
syft number-reverser:<git-sha> \
  -o cyclonedx-json=sbom.json
```

The generated SBOM is uploaded as a GitHub Actions artifact.

This provides an auditable inventory of software components contained in the image.

---

# 7. Image Signing

Cosign is used for keyless container image signing.

The signing process uses the GitHub Actions OIDC identity.

```text
GitHub Actions
      |
      v
OIDC Identity
      |
      v
Cosign
      |
      v
Signed Image
```

No private signing key is committed to the repository.

---

# 8. Image Signature Verification

The image signature is verified before deployment.

Verification validates the expected GitHub Actions identity and OIDC issuer.

The deployment therefore requires a successfully signed artifact.

```text
Image
  |
  v
Signature Verification
  |
  +---- Invalid ----> Deployment blocked
  |
  +---- Valid ------> Deployment continues
```

---

# 9. Immutable Image Identification

The application is not deployed using:

```text
:latest
```

Instead, CI/CD uses the Git commit SHA:

```text
ghcr.io/<owner>/number-reverser:<git-sha>
```

This creates a direct relationship between:

```text
Git commit
      ↓
Container image
      ↓
Kubernetes Deployment
```

---

# 10. Kubernetes Admission Security

Kyverno is installed in the cluster and used for admission policy enforcement.

The implemented policies enforce:

### Privileged container prevention

Privileged containers are not allowed.

### Resource limits

Workloads must define resource limits.

### `latest` tag prevention

Images using the mutable:

```text
:latest
```

tag are not allowed.

These checks occur at Kubernetes admission time.

```text
kubectl apply
      |
      v
Kubernetes API
      |
      v
Kyverno
      |
      +---- Violation ----> Reject
      |
      +---- Compliant ----> Accept
```

---

# 11. Kubernetes Network Segmentation

A Kubernetes NetworkPolicy restricts pod network communication.

The application is not intended to have unrestricted pod-to-pod connectivity.

This provides an additional security boundary on top of AWS networking.

```text
AWS VPC / Security Groups
            +
Kubernetes NetworkPolicy
            =
Layered network controls
```

---

# 12. EKS Secrets Encryption

EKS secret data is configured for encryption using AWS KMS.

Terraform configures:

```hcl
encryption_config = {
  resources = ["secrets"]
}
```

The KMS key is managed through the Terraform EKS/KMS module integration.

---

# 13. EKS Control-Plane Logging

The following EKS control-plane log types are enabled:

```text
api
audit
authenticator
controllerManager
scheduler
```

CloudWatch log retention is configured for:

```text
365 days
```

Audit logging provides visibility into Kubernetes API activity.

---

# 14. Repository Secret Handling

No AWS access keys, private signing keys, passwords, or other sensitive credentials are committed to the repository.

AWS CI/CD authentication is performed using GitHub OIDC.

The current application does not require application-level secret material to operate.

---

# 15. Security Gate Model

The security controls are positioned at different stages of the delivery lifecycle.

```text
Source
  |
  +--> Lint / Unit Tests
  |
  +--> Checkov
  |
  v
Container
  |
  +--> Trivy
  |
  +--> SBOM
  |
  +--> Cosign
  |
  v
Registry
  |
  v
Kubernetes
  |
  +--> Signature verification
  |
  +--> Kyverno
  |
  +--> NetworkPolicy
  |
  v
Running workload
```

The design intentionally uses multiple independent controls rather than relying on a single scanner.

---

# 16. What Is Not Implemented

The following were not added because they were outside the scope of the current implementation:

- External Secrets Operator / AWS Secrets Manager integration
- kube-bench CIS benchmark automation
- Conftest/OPA Terraform plan gating
- Production-scale centralized SIEM integration
- Runtime threat detection
- Multi-region disaster recovery
- Production-grade private-only EKS API architecture

These are considered future improvements rather than controls currently claimed as implemented.

---

# 17. Security Trade-offs

The project was designed within the constraints of a small take-home exercise and AWS cost considerations.

The current EKS API configuration enables both public and private endpoint access.

For a regulated production environment, access to the Kubernetes API would be further restricted.

The current compute footprint is also intentionally small and is not intended to represent production capacity planning.

The important objective was to implement enforceable security controls across:

```text
Infrastructure
CI/CD
Container
Identity
Kubernetes
Network
Encryption
Logging
```
