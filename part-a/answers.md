# Part A — Answers

## Exercise 1: Pod

- **What happens after deleting the Pod, and why?** A standalone Pod is not recreated. No controller is watching it and declaring a desired replica count.
- **Why are standalone Pods rarely used in production?** They do not provide self-healing, replica management, or controlled rollouts. Deployments provide those capabilities.
- **Requests vs. limits:** Requests influence scheduling and represent the resources Kubernetes reserves for placement. Limits cap use: CPU is throttled at its limit, while exceeding a memory limit can cause the container to be terminated with an OOM error.

## Exercise 2: ReplicaSet

- **What happens to the manually created matching Pod?** The ReplicaSet can adopt an otherwise unowned Pod whose labels match its selector. It then counts that Pod toward the desired total and reconciles the count back to three; if there are four matching Pods, it deletes one. Which Pod is removed is not a reliable way to identify the manually created one.
- **Do existing Pods change to `nginx:1.27` when the ReplicaSet template changes?** No. A ReplicaSet maintains a count; it does not roll existing Pods to a new template. New replacement Pods use the updated image. A Deployment is the controller intended for versioned rollouts.

## Exercise 3: Deployment

- **Ownership chain:** A Deployment creates and manages a ReplicaSet; that ReplicaSet creates and maintains the Deployment's Pods.
- **What happens with `nginx:not-a-real-tag`?** The new Pods cannot pull a valid image, so they do not become Ready. With `maxUnavailable: 0`, the Deployment keeps the old Ready Pods while the new ones fail, avoiding an intentional reduction in available replicas. Rollback restores the prior Pod template.
- **Why keep the old ReplicaSet?** Deployments retain prior ReplicaSets as rollout history so they can scale them back during a rollback.

## Exercise 4: ClusterIP

- **How was access checked?** From a temporary Pod, request `http://web-svc` or the fully qualified service name `http://web-svc.default.svc.cluster.local`.
- **What does scaling change?** The Service's selector continues to match the Pods, and its endpoints update as Pods are added or removed. Requests are distributed among the ready endpoints.

## Exercise 5: NodePort

- **Default NodePort range:** `30000-32767` (unless the cluster administrator changes it).
- **How to inspect the port:** `kubectl get svc web-nodeport` or `kubectl describe svc web-nodeport`.
- **Does NodePort also create a ClusterIP?** Yes. A NodePort Service also receives a ClusterIP and supports the usual in-cluster access.
- **When to use each type?** Use ClusterIP for internal cluster traffic. NodePort exposes a port on each node and is useful for this exercise or simple access in a controlled environment; production external traffic commonly uses a LoadBalancer or Ingress.
