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

### Change the API version

Change the single line in [`VERSION`](./VERSION) to `v1`, `v2`, or `v3` and push the change to `main`. The GitHub Actions workflow then builds the API image and deploys it to the Ubuntu K3s server automatically. The server must have the repository's self-hosted GitHub Actions runner installed and online with the `ubuntu1` label.

To run the same deployment manually on Ubuntu:

```bash
bash part-b/deploy.sh
```

The script builds the API image with that tag, embeds the same value as `APP_VERSION`, imports the image into K3s, updates the Deployment, and waits for the rollout. The frontend reads the version from each API response, so its displayed version changes automatically without rebuilding the frontend. Fortune text for each supported version is defined in `api/server.js` under `fortunesByVersion`. To add a version beyond v3, add its fortunes there, allow it in `deploy.sh`, and add a corresponding API test.

### Configure automatic deployment

In the GitHub repository, open **Settings → Actions → Runners → New self-hosted runner**, choose Linux x64, and follow GitHub's displayed commands on `ubuntu1`. Configure the runner with the additional label `ubuntu1`, install it as a service, and verify that it appears online in the repository settings. Keep the runner dedicated to this trusted repository and restrict who can push to `main`: self-hosted runners execute repository workflows on the server.

The runner service account must be able to run `sudo podman` and `sudo k3s` without an interactive password prompt, because workflows have no interactive terminal. Grant only the required commands using a carefully restricted sudoers rule, validate it with `visudo -c`, and run a workflow only after checking the repository's Actions permissions. Do not run untrusted pull-request workflows on this runner.

While the rollout is in progress, refresh the page rapidly. Responses can include both versions while old and new Pods coexist. After the rollout, click the cookie button to verify the version and fortune. To roll back to the previous Deployment revision:

```bash
sudo k3s kubectl rollout undo deployment/fortune-api
sudo k3s kubectl rollout status deployment/fortune-api
```

To redeploy the version selected in `VERSION` after a rollback, run the deployment script again.

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
