# Kubernetes

## 1. Overview

The application is deployed to Amazon EKS using Kubernetes manifests managed through Kustomize.

The Kubernetes configuration is separated from the AWS infrastructure configuration.

```text
Terraform
    |
    +--> VPC
    +--> EKS
    +--> IAM
    +--> KMS
    +--> Node Group

Kustomize / Kubernetes
    |
    +--> Namespace
    +--> Deployment
    +--> Service
    +--> NetworkPolicy
```

---

## 2. Namespace

The application runs in a dedicated namespace:

```text
number-reverser-dev
```

This provides a clear workload boundary for:

- Resource management
- Network policies
- Admission policies
- Operational commands

---

## 3. Kustomize Structure

The environment-specific configuration is represented by:

```text
k8s/
└── overlays/
    └── dev/
```

The deployment image is updated during CI/CD using:

```bash
kustomize edit set image
```

The resulting image contains the Git commit SHA.

---

## 4. Deployment

The application runs as a Kubernetes Deployment.

The Deployment provides:

- Desired replica management
- Pod lifecycle management
- Rolling updates
- Declarative workload configuration

Example workload relationship:

```text
Deployment
    |
    +--> ReplicaSet
            |
            +--> Pod
```

---

## 5. Container Image

The deployment does not use:

```text
:latest
```

Instead, CI/CD updates the deployment to an immutable commit-based tag:

```text
ghcr.io/<owner>/number-reverser:<git-sha>
```

This provides:

- Release traceability
- Reproducibility
- Easier rollback
- Protection against mutable `latest` tags

---

## 6. Service

The application is exposed internally through a Kubernetes Service.

```text
Client
   |
   v
Kubernetes Service
   |
   v
Application Pod
```

The Service provides stable discovery even when individual Pods are replaced.

---

## 7. Resource Management

The workload defines Kubernetes resource requests and limits.

This prevents an individual container from being able to consume unlimited node resources.

The configuration is also compatible with the Kyverno policy requiring workload resource limits.

---

## 8. NetworkPolicy

A Kubernetes NetworkPolicy restricts network communication for the application Pods.

The principle is:

```text
Default
  |
  v
Restricted communication
  |
  +--> Allow only required traffic
```

This prevents unrestricted pod-to-pod communication.

NetworkPolicy provides workload-level segmentation in addition to AWS VPC and security-group controls.

---

## 9. Kyverno

Kyverno is installed in the EKS cluster and provides Kubernetes admission control.

The project uses Kyverno to enforce workload security requirements.

The enforced requirements include:

### No privileged containers

Workloads must not run with privileged containers.

```text
privileged: true
```

is not permitted.

### Resource limits

Workloads are required to define resource limits.

### No `latest` image tags

Images using:

```text
:latest
```

are not permitted.

The deployment therefore uses commit SHA tags.

---

## 10. Admission Flow

The relevant deployment flow is:

```text
kubectl apply
     |
     v
Kubernetes API
     |
     v
Kyverno Admission Policy
     |
     +---- Policy violation ----> REJECT
     |
     +---- Policy compliant ---> ACCEPT
                                      |
                                      v
                                  Pod created
```

This means security policy is enforced by the cluster rather than relying only on developer discipline.

---

## 11. Deployment Verification

After deployment:

```bash
kubectl get deployments -n number-reverser-dev
kubectl get pods -n number-reverser-dev
kubectl get svc -n number-reverser-dev
```

The CI/CD pipeline also waits for:

```bash
kubectl rollout status \
  deployment/number-reverser \
  -n number-reverser-dev \
  --timeout=180s
```

---

## 12. Operational Model

The deployment is declarative.

The desired state is stored in Git and rendered through Kustomize.

```text
Git
 |
 v
Kustomize
 |
 v
Kubernetes manifests
 |
 v
EKS
```

This makes changes reviewable and reproducible.
