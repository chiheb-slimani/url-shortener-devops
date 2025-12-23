# URL Shortener DevOps Project

Small FastAPI URL shortener with SQLite persistence and a full DevOps toolchain
(CI, containerization, Kubernetes, observability, security scans).

## Architecture
- FastAPI app in `app/main.py`
- SQLite database at `DB_PATH` (default `data.db`)
- Metrics at `/metrics`, JSON structured logs, OpenTelemetry traces to console
- GitHub Actions for tests, CodeQL SAST, and ZAP DAST
- Dockerfile and Kubernetes manifests (kind/minikube)

## Requirements
- Python 3.11+
- Docker
- kubectl and kind or minikube

## Local run
1. Create a virtualenv and install deps:
```bash
python -m venv .venv
```
Windows:
```cmd
.venv\Scripts\activate
```
macOS/Linux:
```bash
source .venv/bin/activate
```
Install:
```bash
pip install -r requirements.txt
```
2. Optional env vars:
```cmd
set BASE_URL=http://localhost:8000
set DB_PATH=data.db
```
macOS/Linux:
```bash
export BASE_URL=http://localhost:8000
export DB_PATH=data.db
```
3. Run the API:
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Tests
```bash
pytest
```

## API
- POST `/shorten` with JSON body `{"url":"https://example.com"}`
- GET `/{code}` redirects (302) or returns 404 JSON `{"error":"not found"}`
- GET `/healthz` returns `{"status":"ok"}`
- GET `/metrics` returns Prometheus metrics

## Example curl commands
```bash
curl -s -X POST http://localhost:8000/shorten -H "Content-Type: application/json" -d "{\"url\":\"https://example.com\"}"
curl -v http://localhost:8000/<code>
curl -s http://localhost:8000/healthz
curl -s http://localhost:8000/metrics | head
```

## Docker
```bash
docker build -t url-shortener .
docker run -p 8000:8000 -e BASE_URL=http://localhost:8000 -e DB_PATH=/data/urls.db -v url-data:/data url-shortener
```

## Kubernetes (kind or minikube)
1. Update the image in `k8s/deployment.yaml` to your Docker Hub image.
2. Create a cluster:
Kind:
```bash
kind create cluster --name url-shortener
```
Minikube install (PowerShell):
```powershell
New-Item -Path 'c:\' -Name 'minikube' -ItemType Directory -Force
$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -OutFile 'c:\minikube\minikube.exe' -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' -UseBasicParsing
```
Minikube start:
```bash
minikube start
```
3. Apply manifests:
```bash
kubectl apply -f k8s/
```
4. Port-forward:
```bash
kubectl port-forward svc/url-shortener 8000:8000
```

Optional ingress:
```bash
kubectl apply -f k8s/ingress.yaml
```

## Observability
- Metrics: `/metrics` exposes `request_count` and `request_latency_seconds`
- Logs: JSON structured logs with timestamp, method, path, status, duration_ms, request_id
- Tracing: OpenTelemetry spans exported to console

## CI/CD and Security
- `.github/workflows/ci.yaml` runs tests on PRs and builds the Docker image on main (optional push).
- `.github/workflows/codeql.yaml` runs CodeQL SAST on push/PR.
- `.github/workflows/dast.yaml` runs OWASP ZAP baseline scan on main and uploads a report.
- Docker push uses either `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN` or `DOCKER_USERNAME` + `DOCKER_PASSWORD` secrets.

## How to demo
1. Start the API locally or with Docker.
2. Shorten a URL with `/shorten` and copy the returned code.
3. Request `/{code}` and show the 302 redirect.
4. Show `/metrics` and JSON request logs in the console.
5. Point to CodeQL and ZAP runs in GitHub Actions.
