
---

# 5. `docs/KUBERNETES.md`

```markdown
# Kubernetes

## Overview

The application runs on Amazon EKS.

Kubernetes configuration is maintained as manifests and deployed using Kustomize.

The development environment is represented by:

```text
k8s/overlays/dev


Namespace

The application is deployed into:

number-reverser-dev

Keeping the application in its own namespace provides a clear workload boundary and gives policies and operational commands a well-defined scope.

Deployment

The application is deployed as a Kubernetes Deployment.

The deployment provides Kubernetes-managed replica lifecycle and rolling update behavior.

The image is updated during CI/CD to:

ghcr.io/<owner>/number-reverser:<git-sha>

The Git SHA provides traceability between:

Git commit
     |
Docker image
     |
GHCR artifact
     |
Kubernetes deployment
Service

A Kubernetes Service provides stable access to the application pods.

The Service abstracts the individual pod IP addresses and allows Kubernetes to route traffic to healthy application endpoints.

Kustomize

Kustomize separates reusable Kubernetes configuration from environment-specific configuration.

The deployment pipeline uses:

kubectl apply -k k8s/overlays/dev

The image is updated without modifying the base deployment definition manually.

Resource Controls

Application workloads define resource requirements/limits where configured in the Kubernetes manifests.

This prevents the workload from being completely unconstrained from a cluster resource perspective.

NetworkPolicy

A Kubernetes NetworkPolicy is used to restrict pod network communication.

The purpose is to avoid unrestricted pod-to-pod connectivity.

The policy should be viewed as a workload-level security boundary:

Allowed traffic
      |
      v
Application Pod

Unexpected pod-to-pod traffic
      |
      v
Blocked

This is defense in depth in addition to AWS VPC and security-group controls.

Kyverno

Kyverno is installed into the cluster using Helm.

The deployed chart version is:

3.9.0

The Kyverno application version observed in the environment is:

v1.19.0

Kyverno provides Kubernetes admission control.

The purpose is to prevent insecure workload configurations from being admitted to the cluster.

The policies in this project address the security requirements specified for the workload, including:

preventing privileged workloads
requiring resource controls
preventing mutable latest image usage
Why Kyverno

Kyverno was selected because policies can be expressed directly against Kubernetes resources without requiring application developers to learn a separate policy language.

This makes the policies easier to review alongside the Kubernetes manifests.

Deployment Verification

The CI/CD pipeline verifies the cluster before deployment:

kubectl get nodes

After deployment it waits for the application rollout:

kubectl rollout status \
  deployment/number-reverser \
  -n number-reverser-dev \
  --timeout=180s

It then checks:

kubectl get deployments -n number-reverser-dev
kubectl get pods -n number-reverser-dev
kubectl get svc -n number-reverser-dev
Operational Security Model

The Kubernetes security model is layered:

AWS IAM
   |
EKS Access Control
   |
AWS VPC / Security Groups
   |
Private Worker Nodes
   |
Kubernetes Namespace
   |
NetworkPolicy
   |
Kyverno Admission Policies
   |
Non-root Container
   |
Application

No single control is treated as the complete security boundary.
