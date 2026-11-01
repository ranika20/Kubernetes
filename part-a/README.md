# Part A — Run the exercises

Run these exercises in order against a Kubernetes cluster. From this directory, each manifest can be applied with `kubectl apply -f <file>`. Capture the requested terminal screenshots in `screenshots/`.

## 1. Pod

```powershell
kubectl apply -f .\pod.yaml
kubectl get pods -o wide
kubectl describe pod web-pod
kubectl exec -it web-pod -- sh
```

In the container, run `wget -qO- http://localhost`, then exit with `exit`. Capture the Pod details. Delete it with `kubectl delete -f .\pod.yaml` and observe that it is not recreated.

## 2. ReplicaSet

```powershell
kubectl apply -f .\replicaset.yaml
kubectl get pods -l app=web-rs
kubectl get pods -l app=web-rs -w
```

In another terminal, delete one of the listed Pods and watch the ReplicaSet create a replacement. Apply `manual-pod.yaml` and observe how the matching Pod affects the ReplicaSet's replica count.

Change the image in `replicaset.yaml` to `nginx:1.27`, then:

```powershell
kubectl apply -f .\replicaset.yaml
kubectl get pods -l app=web-rs -o wide
kubectl describe pod <pod-name>
```

The existing Pods do not roll automatically just because a ReplicaSet template changed. Delete the ReplicaSet after recording the results:

```powershell
kubectl delete -f .\replicaset.yaml
```

## 3. Deployment

```powershell
kubectl apply -f .\deployment.yaml
kubectl get deployments,replicasets,pods
```

Capture the owner chain. Change the image in `deployment.yaml` to `nginx:1.27`, apply it, and wait for the rollout:

```powershell
kubectl apply -f .\deployment.yaml
kubectl rollout status deployment/web
kubectl get replicasets
```

Capture the ReplicaSets. Next, change the image to `nginx:not-a-real-tag`, apply it, and inspect the Pods:

```powershell
kubectl apply -f .\deployment.yaml
kubectl get pods
kubectl rollout undo deployment/web
kubectl rollout history deployment/web
```

Leave the Deployment running for the Service exercises.

## 4. ClusterIP Service

Apply the Service, then launch a temporary shell Pod:

```powershell
kubectl apply -f .\svc-clusterip.yaml
kubectl run tmp --rm -it --restart=Never --image=busybox -- sh
```

Inside the shell, check both `wget -qO- http://web-svc` and `wget -qO- http://web-svc.default.svc.cluster.local`, then exit. In a separate terminal, scale the Deployment to five replicas and inspect the Service endpoints:

```powershell
kubectl get endpoints web-svc
kubectl scale deployment/web --replicas=5
kubectl get endpoints web-svc
```

## 5. NodePort Service

```powershell
kubectl apply -f .\svc-nodeport.yaml
kubectl get svc web-nodeport
kubectl get nodes -o wide
```

Open `http://<node-ip>:30090` in a browser. Capture the Service and browser output, and answer the NodePort questions in `answers.md`.
