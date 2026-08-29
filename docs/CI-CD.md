# CI/CD Pipeline

## 1. Pipeline Objective

The pipeline is designed to prevent untested, vulnerable, unsigned, or non-compliant workloads from reaching the Kubernetes cluster.

The pipeline separates application testing, infrastructure validation, container security, and deployment.

---

## 2. Pipeline Flow

```text
                         Git Push / Pull Request
                                  |
                                  v
                         +-------------------+
                         | Lint + Unit Tests |
                         +---------+---------+
                                   |
                                   v
                     +---------------------------+
                     | Terraform Validation      |
                     | Terraform Plan             |
                     | Checkov                    |
                     +-------------+-------------+
                                   |
                                   v
                     +---------------------------+
                     | Docker Build               |
                     +-------------+-------------+
                                   |
                                   v
                     +---------------------------+
                     | Trivy Image Scan           |
                     | CRITICAL = Pipeline Fail  |
                     +-------------+-------------+
                                   |
                                   v
                     +---------------------------+
                     | Syft SBOM                  |
                     +-------------+-------------+
                                   |
                                   v
                     +---------------------------+
                     | Push Image to GHCR         |
                     +-------------+-------------+
                                   |
                                   v
                     +---------------------------+
                     | Cosign Sign                |
                     +-------------+-------------+
                                   |
                                   v
                     +---------------------------+
                     | Cosign Verify              |
                     +-------------+-------------+
                                   |
                                   v
                     +---------------------------+
                     | Deploy to EKS              |
                     | Kustomize                  |
                     +-------------+-------------+
                                   |
                                   v
                     +---------------------------+
                     | Rollout Verification       |
                     +---------------------------+
```

---

## 3. Triggering

The workflow runs for:

```text
push → main
pull_request → main
```

Deployment is restricted to pushes to the `main` branch.

This prevents pull requests from directly deploying workloads.

---

# 4. Stage 1 — Application Quality

The first stage performs:

```text
Python setup
Dependency installation
Ruff linting
Pytest unit tests
```

Commands include:

```bash
ruff check app/
pytest -q
```

If linting or unit tests fail, downstream stages do not execute.

---

# 5. Stage 2 — Infrastructure Validation

Terraform is initialized and validated.

The stage performs:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -input=false
```

The pipeline also authenticates to AWS using GitHub OIDC.

No long-lived AWS access key is stored in GitHub Actions.

---

# 6. Stage 3 — IaC Security

Checkov scans the Terraform configuration.

```bash
checkov \
  -d . \
  --framework terraform \
  --download-external-modules true
```

The objective is to detect insecure infrastructure configuration before deployment.

---

# 7. Stage 4 — Docker Build

The application image is built using the repository Dockerfile.

The image is tagged using the Git commit SHA:

```text
number-reverser:<git-sha>
```

Using the commit SHA provides immutable application-version traceability.

---

# 8. Stage 5 — Container Vulnerability Scanning

Trivy scans the built container image.

The pipeline is configured to fail on Critical vulnerabilities.

Conceptually:

```bash
trivy image \
  --severity CRITICAL \
  --exit-code 1 \
  number-reverser:<git-sha>
```

The important behavior is:

```text
Critical vulnerability
        |
        v
Pipeline failure
        |
        X
No deployment
```

The scan is therefore a release gate rather than a reporting-only step.

---

# 9. Stage 6 — SBOM

Syft generates a CycloneDX JSON Software Bill of Materials.

```bash
syft number-reverser:<git-sha> \
  -o cyclonedx-json=sbom.json
```

The SBOM is uploaded as a GitHub Actions artifact.

This provides visibility into the packages included in the container image.

---

# 10. Stage 7 — Image Publication

For pushes to `main`, the image is published to GitHub Container Registry.

Example:

```text
ghcr.io/<owner>/number-reverser:<git-sha>
```

The registry image is tied to the source commit through the SHA tag.

---

# 11. Stage 8 — Image Signing

Cosign is used for keyless image signing.

GitHub Actions provides the OIDC identity used by Cosign.

The signing model is:

```text
GitHub Actions
      |
      | OIDC identity
      v
Cosign
      |
      v
Signed OCI Image
```

No private signing key is stored in the repository.

---

# 12. Stage 9 — Signature Verification

Before deployment, the image signature is verified.

Verification checks the expected GitHub Actions OIDC identity and issuer.

The deployment therefore depends on both:

```text
Image exists
     AND
Image signature is valid
```

---

# 13. Stage 10 — Kubernetes Deployment

The deployment job:

1. Authenticates to AWS.
2. Updates kubeconfig.
3. Verifies EKS access.
4. Installs Kustomize.
5. Updates the image reference.
6. Renders the manifests.
7. Applies the Kubernetes configuration.
8. Waits for the rollout.
9. Verifies the resulting resources.

The deployed image is:

```text
ghcr.io/<owner>/number-reverser:<git-sha>
```

---

# 14. Stage 11 — Rollout Verification

The pipeline waits for the Kubernetes Deployment to become ready.

```bash
kubectl rollout status \
  deployment/number-reverser \
  -n number-reverser-dev \
  --timeout=180s
```

It then checks:

```bash
kubectl get deployments
kubectl get pods
kubectl get svc
```

A failed rollout causes the deployment job to fail.

---

# 15. Authentication Model

GitHub Actions authenticates to AWS using:

```text
GitHub OIDC
     |
     v
AWS IAM Role
     |
     v
AWS API
```

The role is:

```text
GitHubActions-NumberReverser
```

The workflow uses:

```yaml
permissions:
  id-token: write
  contents: read
```

This avoids storing static AWS access keys in GitHub Secrets.

---

# 16. Pull Request vs Main Branch

The pipeline distinguishes validation from deployment.

### Pull Request

Runs validation/security checks but does not deploy.

### Main branch

Runs the complete release flow and deploys the approved image to EKS.

This prevents arbitrary pull-request code from being deployed to the cluster.

---

# 17. Security Gates

The important gates are:

| Gate | Failure Result |
|---|---|
| Ruff | Pipeline fails |
| Unit tests | Pipeline fails |
| Terraform validation | Pipeline fails |
| Checkov | Security gate |
| Trivy Critical | Pipeline fails |
| Image signing | Pipeline fails |
| Signature verification | Pipeline fails |
| Kubernetes rollout | Deployment fails |

The goal is to make security controls enforceable rather than informational.
