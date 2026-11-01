# Fortune Cookie Factory

A small Node.js/Express API and Nginx frontend deployed to Kubernetes. The browser requests `/api/fortune` from Nginx; Nginx forwards it to the internal `fortune-api` ClusterIP Service. Each response includes a random fortune, the serving Pod hostname, and its application version.

## Prerequisites

- Docker Desktop with Kubernetes enabled, or Minikube.
- `kubectl`, Docker, and Node.js 20 or newer.
- A Kubernetes node in `Ready` state: `kubectl get nodes`.

The supplied SSH alias `ubuntu1` is not required for local-cluster work. To run this on a remote cluster instead, first configure a valid SSH key and Kubernetes context on that machine.

## Build the images

From the project root in PowerShell:

```powershell
Push-Location .\part-b\api
npm ci
npm test
Pop-Location

docker build --build-arg APP_VERSION=v1 -t fortune-api:v1 .\part-b\api
docker build -t fortune-web:v1 .\part-b\frontend
```

For Minikube, build into its Docker engine before building:

```powershell
& minikube docker-env --shell powershell | Invoke-Expression
```

For Docker Desktop Kubernetes, build using the Docker Desktop engine selected by `docker context show`.

## Deploy and open the site

```powershell
kubectl apply -f .\part-b\k8s\fortune-api-deployment.yaml
kubectl apply -f .\part-b\k8s\fortune-api-service.yaml
kubectl apply -f .\part-b\k8s\fortune-web-deployment.yaml
kubectl apply -f .\part-b\k8s\fortune-web-service.yaml

kubectl rollout status deployment/fortune-api
kubectl rollout status deployment/fortune-web
kubectl get pods,services
```

Open `http://localhost:30090` with Docker Desktop. With Minikube, run `minikube service fortune-web --url` and open the URL it prints. If accessing a remote node, ensure TCP port 30090 is allowed by its firewall.

To confirm the API distributes requests across Pods, open a shell in a temporary Pod and request it several times:

```powershell
kubectl run tmp --rm -it --restart=Never --image=busybox -- wget -qO- http://fortune-api:3000/api/fortune
```

Repeat the command to observe different `pod` values.

## Experiments

### Pod recovery and scaling

Watch the Pods in one terminal:

```powershell
kubectl get pods -l app=fortune-api -w
```

In another terminal, delete one API Pod. Get its current name with `kubectl get pods -l app=fortune-api`, then run `kubectl delete pod <pod-name>`. The Deployment creates a replacement. Record what you observe and the recovery time in this README; take a screenshot in `screenshots/`.

Scale the API to six replicas, then back to one:

```powershell
kubectl scale deployment/fortune-api --replicas=6
kubectl get pods -l app=fortune-api
kubectl scale deployment/fortune-api --replicas=1
```

Observe how the number of available API Pods affects the service's capacity and resilience.

### Version rollout and rollback

Build the v2 API image:

```powershell
docker build --build-arg APP_VERSION=v2 -t fortune-api:v2 .\part-b\api
```

Edit `fortune-api-deployment.yaml`: change the image to `fortune-api:v2` and `APP_VERSION` to `v2`, then apply the manifest:

```powershell
kubectl apply -f .\part-b\k8s\fortune-api-deployment.yaml
kubectl rollout status deployment/fortune-api
```

While the rollout is in progress, refresh the page rapidly. Responses can include both v1 and v2 while old and new Pods coexist; each response identifies its Pod and version. When the rollout completes, use the browser to verify v2 fortunes, then roll back:

```powershell
kubectl rollout undo deployment/fortune-api
kubectl rollout status deployment/fortune-api
```

The Deployment manifest is left at its initial v1 settings in this project; reapply it after the experiment if you changed it.

## Architecture

```text
Browser
  -> fortune-web NodePort :30090
  -> Nginx frontend Pods :80
  -> fortune-api ClusterIP Service :3000
  -> three Node.js API Pods
```

The browser calls the same-origin path `/api/fortune`; it does not call the API Service directly. Kubernetes DNS names such as `fortune-api` resolve inside the cluster, not in the user's browser. Nginx proxies that path to the API Service, which balances requests among ready API Pods.

Nginx resolves the fully qualified API Service name (`fortune-api.default.svc.cluster.local`) through the cluster DNS Service. If your cluster uses a different DNS Service IP than the default `10.43.0.10`, update the `resolver` directive in `frontend/nginx.conf` before building the frontend image.

The API readiness probe prevents an unready Pod from receiving Service traffic. Its liveness probe restarts an unhealthy container. Both API and frontend containers have CPU and memory requests/limits.

## Part A

Part A manifests and short conceptual answers are in `..\part-a\`. Run its exercises in order and save the requested terminal screenshots under `..\part-a\screenshots\`.

## Cleanup

```powershell
kubectl delete -f .\part-b\k8s\fortune-web-service.yaml
kubectl delete -f .\part-b\k8s\fortune-web-deployment.yaml
kubectl delete -f .\part-b\k8s\fortune-api-service.yaml
kubectl delete -f .\part-b\k8s\fortune-api-deployment.yaml
```

## Observed experiment results

Fill in actual results after running the experiments; do not infer timings or screenshots without testing the cluster.

- Pod deletion and recovery:
- Results with six API replicas:
- Results with one API replica:
- v1/v2 responses during rollout:
- Rollback verification:
