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

Change the single line in [`VERSION`](./VERSION) to `v1`, `v2`, `v3`, or `v4`. To automatically sync a Windows-local edit to Ubuntu, first create an SSH key if needed, authorize its public key on the server, then start the local watcher:

```powershell
ssh-keygen -t ed25519
Get-Content "$env:USERPROFILE\.ssh\fortune-k8s.pub" | ssh ubuntu1 "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys"
powershell -ExecutionPolicy Bypass -File .\part-b\watch-local-version.ps1
```

Run `ssh-keygen` only if you do not already have `id_ed25519` keys; do not overwrite an existing key. The key setup prompts for the Ubuntu password once. The PowerShell watcher then copies the project version and API source to Ubuntu, installs/restarts the Ubuntu systemd watcher (which may prompt once for `sudo`), and monitors the local `VERSION` file. Keep its window open. On each save, it syncs the API source and version to Ubuntu; the systemd service builds the image, imports it into K3s, and rolls out the Deployment. No GitHub push is needed. Alternatively, edit the server copy through Remote-SSH; the systemd watcher detects that directly.

Check watcher status and logs:

```bash
sudo systemctl status fortune-api-version-watcher
sudo journalctl -u fortune-api-version-watcher -f
```

To apply the selected version manually instead:

```bash
bash /home/ran/part-b/deploy.sh
```

The deployment script builds the API image with that tag, embeds the same value as `APP_VERSION`, imports the image into K3s, updates the Deployment, and waits for the rollout. The frontend reads the version from each API response, so its displayed version changes automatically without rebuilding the frontend. Fortune text for each supported version is defined in `api/server.js` under `fortunesByVersion`. To add a version beyond v4, add its fortunes there, allow it in `deploy.sh`, `watch-version.sh`, and `watch-local-version.ps1`, and add a corresponding API test.

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
