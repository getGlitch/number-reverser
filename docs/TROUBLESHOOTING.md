
---

# 8. `docs/TROUBLESHOOTING.md`

This is actually a **very good document for your interview**, because it demonstrates real debugging rather than definitions.

```markdown
# Troubleshooting

This document records the significant implementation issues encountered while building the project and the resolution used.

---

## 1. Terraform Plan Reported KMS Policy Changes

### Symptom

Terraform reported an in-place update to the EKS KMS key policy.

The plan showed the KMS principal changing from the account root principal to the GitHub Actions IAM role.

### Investigation

The KMS key is created internally by the EKS module through the KMS module.

The EKS module passes KMS policy inputs including:

```text
key_owners
key_administrators
key_users


The module also adds the EKS cluster role as a key user.

The relevant configuration was inspected directly inside:

.terraform/modules/eks.kms
Resolution

The EKS module's actual KMS policy construction was inspected instead of manually creating a second KMS policy.

The Terraform configuration was then aligned with the intended IAM principals.

After the correction:

terraform plan

returned:

No changes.
Your infrastructure matches the configuration.
Lesson

When a Terraform module creates a nested resource, the first step should be to inspect the module's input variables and generated policy rather than attempting to override the resource blindly.

2. EKS Access Entry Configuration
Symptom

The cluster required explicit EKS access configuration for the GitHub Actions role.

Investigation

The Terraform state showed EKS access entries and policy associations.

The relevant access configuration used:

principal_arn
AmazonEKSClusterAdminPolicy
cluster access scope
Resolution

The access entries were managed through the EKS module:

access_entries = {
  github_actions = {
    principal_arn = "..."
    ...
  }
}

The GitHub Actions IAM role was granted the required EKS access policy.

Verification

The Terraform refresh showed:

aws_eks_access_entry.this["github_actions"]

and:

aws_eks_access_policy_association.this["github_actions_admin"]
Lesson

AWS IAM authentication and Kubernetes authorization are separate concerns.

Having an IAM role does not automatically mean that the role has the required EKS permissions.

3. Terraform Drift Detection
Symptom

Terraform reported:

Objects have changed outside of Terraform

during a plan.

Investigation

Terraform refresh compared the recorded state against the current AWS infrastructure.

The plan identified resources whose observed AWS attributes differed from the previous state.

Resolution

The actual infrastructure and Terraform configuration were compared before deciding whether the difference represented legitimate AWS-managed state or configuration drift.

Lesson

A Terraform plan is not only a deployment mechanism.

It is also an important mechanism for detecting infrastructure drift.

4. Container Security Scan
Symptom

The container needed to satisfy the security requirement that Critical vulnerabilities fail the pipeline.

Implementation

The same Trivy gate was used in CI:

trivy image \
  --severity CRITICAL \
  --exit-code 1 \
  number-reverser:${GITHUB_SHA}
Verification

The image was also scanned locally before relying on the CI result.

The scan inspected both:

operating-system packages
Python dependencies
Lesson

A scanner is useful only when its result affects the release decision.

The important configuration is:

--exit-code 1

because it turns a vulnerability finding into a pipeline failure.

5. Cosign Signing Failed Against GHCR
Symptom

Cosign produced:

UNAUTHORIZED: authentication required

when attempting to sign the GHCR image.

Investigation

The image had already been built and tagged, but Cosign still needed registry access to resolve the image reference.

The command was attempting to access:

ghcr.io/getglitch/number-reverser:<sha>

without authenticated registry access.

Resolution

The pipeline was structured so that the GHCR login occurs before the image is signed:

Docker Build
    |
Trivy
    |
Syft
    |
GHCR Login
    |
Image Push
    |
Cosign Sign
    |
Cosign Verify

The GitHub Actions token is used for GHCR authentication.

Additional Note

Cosign also warns that signing by mutable tags is less robust than signing a digest.

A production refinement would capture the pushed image digest and perform signing and verification against:

image@sha256:<digest>

rather than only the SHA tag.

Lesson

Container signing is part of the registry workflow.

Build success alone does not guarantee that the signing tool can resolve or access the published artifact.

6. Kubernetes Deployment Verification
Symptom

A successful:

kubectl apply

does not necessarily mean that the application is healthy.

Resolution

The deployment pipeline explicitly waits for the rollout:

kubectl rollout status \
  deployment/number-reverser \
  -n number-reverser-dev \
  --timeout=180s

It then checks:

kubectl get deployments
kubectl get pods
kubectl get svc
Lesson

Deployment should be treated as:

Apply
  +
Rollout
  +
Verification

rather than assuming that kubectl apply alone represents a successful release.

7. Kustomize Image Update
Symptom

The deployment needs to use the exact image generated by the current GitHub Actions run.

Resolution

The pipeline updates the development overlay using:

kustomize edit set image \
  ghcr.io/getglitch/number-reverser=ghcr.io/getglitch/number-reverser:${GITHUB_SHA}

The rendered configuration is inspected before deployment.

Verification

The pipeline runs:

kubectl kustomize k8s/overlays/dev | grep "image:"

before applying the manifests.

Lesson

Rendering the Kubernetes manifests before deployment catches incorrect image substitutions before they reach the cluster.

General Debugging Approach

The troubleshooting approach used throughout the project was:

Observe
  |
Identify the failing layer
  |
Inspect actual state
  |
Inspect module/tool behavior
  |
Make the smallest configuration change
  |
Run the relevant validation
  |
Run the complete pipeline
  |
Verify the final state

This prevents fixing symptoms without understanding the underlying resource or pipeline behavior.



---

## Final repository layout

I recommend committing it exactly like this:

```text
number-reverser/
│
├── README.md
├── SECURITY.md
│
├── docs/
│   ├── ARCHITECTURE.md
│   ├── TERRAFORM.md
│   ├── CI-CD.md
│   ├── KUBERNETES.md
│   ├── DEPLOYMENT.md
│   └── TROUBLESHOOTING.md
│
├── app/
├── terraform/
├── k8s/
├── Dockerfile
├── .dockerignore
│
└── .github/
    └── workflows/
        └── ci-cd.yml
