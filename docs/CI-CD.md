
---

# 4. `docs/CI-CD.md`

```markdown
# CI/CD Pipeline

## Objective

The pipeline is designed to prevent untested or insecure application changes from reaching the Kubernetes cluster.

The workflow is triggered by:

```yaml
push:
  branches:
    - main

pull_request:
  branches:
    - main



Pipeline Flow


                    Pull Request / Push
                            |
                            v
                    +---------------+
                    | Lint & Tests  |
                    +---------------+
                            |
                            v
                    +---------------+
                    | Terraform     |
                    | Security      |
                    +---------------+
                            |
                            v
                    +---------------+
                    | Docker Build  |
                    +---------------+
                            |
                            v
                    +---------------+
                    | Trivy Scan    |
                    +---------------+
                            |
                            v
                    +---------------+
                    | SBOM / Syft   |
                    +---------------+
                            |
                    main push only
                            |
                            v
                    +---------------+
                    | GHCR Push     |
                    +---------------+
                            |
                            v
                    +---------------+
                    | Cosign Sign   |
                    +---------------+
                            |
                            v
                    +---------------+
                    | Cosign Verify |
                    +---------------+
                            |
                            v
                    +---------------+
                    | EKS Deploy    |
                    +---------------+
                            |
                            v
                    +---------------+
                    | Rollout Check |
                    +---------------+




Stage 1 — Lint and Unit Tests

Python 3.12 is used.

Dependencies are installed and Ruff performs static linting.

Tests are executed using:

pytest -q

A test failure stops downstream stages.

Stage 2 — Terraform Security

Checkov scans the Terraform configuration:

checkov \
  -d terraform \
  --framework terraform \
  --download-external-modules true

This checks the infrastructure code for security and configuration issues before deployment.

Stage 3 — Terraform Validation

The Terraform stage performs:

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -input=false

AWS authentication is performed using the GitHub OIDC role.

The pipeline verifies the identity using:

aws sts get-caller-identity
Stage 4 — Docker Build

The application image is built using:

docker build \
  -t number-reverser:${{ github.sha }} \
  .

The Git commit SHA is used as the immutable application version identifier.

Stage 5 — Trivy

Trivy scans the built image.

The current pipeline gates on:

CRITICAL

The important configuration is:

--severity CRITICAL
--exit-code 1

Therefore a Critical vulnerability causes the job to fail.

This is a real pipeline gate rather than a report-only scan.

Stage 6 — SBOM

Syft generates a CycloneDX JSON SBOM:

syft number-reverser:${{ github.sha }} \
  -o cyclonedx-json=sbom.json

The SBOM is uploaded as a GitHub Actions artifact.

This provides a software component inventory for the exact image produced by the build.

Stage 7 — Container Registry

For pushes to main, the image is tagged:

ghcr.io/<owner>/number-reverser:<git-sha>

and pushed to GitHub Container Registry.

Pull requests do not publish deployment images.

Stage 8 — Cosign

The container image is signed using Cosign.

Keyless signing uses GitHub Actions OIDC identity.

The signature is then verified using the GitHub Actions certificate identity and Sigstore OIDC issuer.

The verification step checks that the signature originates from the expected GitHub Actions workflow identity.

Stage 9 — Deployment

Deployment occurs only for:

push to main

The workflow authenticates to AWS and configures EKS access:

aws eks update-kubeconfig \
  --name number-reverser \
  --region ap-south-1

Cluster connectivity is verified using:

kubectl get nodes
Stage 10 — Kustomize

The deployment overlay is:

k8s/overlays/dev

The image reference is updated to the current Git SHA.

The rendered manifest is inspected before applying it.

Stage 11 — Kubernetes Deployment

The manifests are applied using:

kubectl apply -k k8s/overlays/dev

The rollout is then monitored:

kubectl rollout status \
  deployment/number-reverser \
  -n number-reverser-dev \
  --timeout=180s

Finally:

kubectl get deployments
kubectl get pods
kubectl get svc

are used to verify the deployed resources.

Pull Request Behavior

Pull requests run validation and security stages but do not deploy to EKS.

This prevents unmerged changes from reaching the development cluster.

Main Branch Behavior

A successful push to main progresses through:

Test
  ↓
Security
  ↓
Terraform Plan
  ↓
Image Publish
  ↓
Image Signing
  ↓
Signature Verification
  ↓
EKS Deployment
  ↓
Rollout Verification

Why the Pipeline Is Structured This Way

Each stage has a specific responsibility:


| Stage              | Purpose                          |
| ------------------ | -------------------------------- |
| Lint               | Code quality                     |
| Unit tests         | Application correctness          |
| Checkov            | IaC security                     |
| Terraform validate | Configuration correctness        |
| Terraform plan     | Infrastructure change visibility |
| Docker build       | Reproducible artifact            |
| Trivy              | Vulnerability gate               |
| Syft               | Software inventory               |
| GHCR               | Artifact storage                 |
| Cosign             | Artifact provenance/integrity    |
| EKS deployment     | Delivery                         |
| Rollout check      | Deployment verification          |

