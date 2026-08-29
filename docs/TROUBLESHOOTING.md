# Troubleshooting

This document records the main implementation and troubleshooting issues encountered while building the project.

---

## 1. Terraform Plan Showing KMS Policy Changes

### Symptom

Terraform initially showed an in-place update to the EKS KMS key policy.

The plan showed the KMS policy principal changing between IAM identities.

Example:

```text
Terraform will perform the following actions:

module.eks.module.kms.aws_kms_key.this[0]
will be updated in-place
```

### Investigation

The EKS module internally manages the KMS module and builds the key policy from:

```text
key_owners
key_administrators
key_users
```

The module configuration was inspected directly under:

```text
.terraform/modules/eks.kms/
```

The EKS module's KMS configuration was also inspected to understand how the policy was being generated.

### Resolution

The configuration was reviewed and Terraform was re-run until the resulting configuration matched the intended infrastructure.

Final validation:

```text
No changes. Your infrastructure matches the configuration.
```

This confirmed that Terraform state and configuration were synchronized.

---

# 2. EKS Access Entry Configuration

### Symptom

The cluster required explicit access for the GitHub Actions deployment role.

### Resolution

EKS access entries were configured through Terraform.

The GitHub Actions role:

```text
arn:aws:iam::598907064200:role/GitHubActions-NumberReverser
```

was associated with:

```text
AmazonEKSClusterAdminPolicy
```

at cluster scope.

The cluster creator bootstrap admin permission was disabled:

```hcl
enable_cluster_creator_admin_permissions = false
```

This made the access configuration explicit in Terraform.

---

# 3. GitHub Actions AWS Authentication

### Problem

The CI/CD workflow needed AWS access without storing long-lived AWS access keys.

### Resolution

GitHub Actions OIDC was used.

```text
GitHub Actions
      |
      | OIDC token
      v
AWS IAM
      |
      v
GitHubActions-NumberReverser
```

The workflow uses:

```yaml
permissions:
  id-token: write
  contents: read
```

AWS identity can be verified using:

```bash
aws sts get-caller-identity
```

---

# 4. Cosign Image Signing Authentication

### Symptom

Cosign signing initially failed with:

```text
UNAUTHORIZED: authentication required
```

The error occurred because Cosign needed authenticated access to the GHCR image.

### Cause

The workflow was attempting to sign an image stored in GitHub Container Registry without the required registry authentication being available to the signing step.

### Resolution

The GHCR authentication flow was corrected so that the workflow authenticates to the registry before performing image signing and verification.

The final signing flow is:

```text
Build
  ↓
Scan
  ↓
Login to GHCR
  ↓
Push image
  ↓
Cosign sign
  ↓
Cosign verify
```

The image is referenced using the Git commit SHA.

---

# 5. Cosign Tag Warning

### Symptom

Cosign reported:

```text
Image reference uses a tag, not a digest
```

### Meaning

A tag such as:

```text
number-reverser:<git-sha>
```

is more mutable than an OCI digest.

### Engineering Consideration

The Git SHA tag provides application-version traceability, while a production-grade signing workflow can additionally resolve the pushed image to its immutable digest and sign that digest.

The signing design therefore recognizes the distinction between:

```text
Tag
```

and:

```text
Digest
```

and can be extended to use digest-based signing for stronger artifact identity.

---

# 6. Terraform Drift Validation

After infrastructure changes, Terraform was used to compare the actual AWS resources with the declared configuration.

The successful result was:

```text
No changes.
Your infrastructure matches the configuration.
```

This confirms that the Terraform state accurately represents the intended infrastructure at the time of validation.

---

# 7. Kubernetes Deployment Verification

After deploying the application, the following checks are used:

```bash
kubectl get nodes
kubectl get deployments -n number-reverser-dev
kubectl get pods -n number-reverser-dev
kubectl get svc -n number-reverser-dev
```

The rollout is additionally checked using:

```bash
kubectl rollout status \
  deployment/number-reverser \
  -n number-reverser-dev \
  --timeout=180s
```

This prevents the pipeline from reporting a successful deployment before Kubernetes has actually completed the rollout.

---

# 8. Debugging Approach

The troubleshooting approach used throughout the project was:

```text
Observe failure
     ↓
Read exact error
     ↓
Identify responsible layer
     ↓
Inspect Terraform/module/workflow state
     ↓
Make smallest required change
     ↓
Run validation
     ↓
Verify actual infrastructure
```

The objective was to avoid making unrelated changes when troubleshooting infrastructure or CI/CD failures.
