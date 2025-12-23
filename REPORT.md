# URL Shortener DevOps Report

Author:
Date:

## Summary
Describe the project goals, final outcome, and what was delivered.

## Architecture
- FastAPI service with SQLite persistence.
- REST endpoints: /shorten, /{code}, /healthz, /metrics.
- High-level data flow (request -> validation -> DB -> response).

## Storage
- SQLite database (`data.db`), table `urls(code TEXT PRIMARY KEY, url TEXT)`.
- In Kubernetes, data stored on an emptyDir volume (ephemeral).

## CI/CD
- Tests: pytest via GitHub Actions.
- SAST: CodeQL workflow on push/PR.
- DAST: OWASP ZAP baseline scan against a running container.
- Docker build and optional push to Docker Hub.

## Observability
- Metrics: Prometheus `request_count` and `request_latency_seconds`.
- Logs: JSON structured logs with request_id, method, path, status, duration_ms, timestamp.
- Tracing: OpenTelemetry spans exported to console.

## Kubernetes Deployment
- kind/minikube manifests in `k8s/`.
- Deployment with 1 replica and ClusterIP service.
- Port-forwarding used for local access.

## Security Findings
- CodeQL results:
- ZAP baseline results:
- Mitigations/actions taken:

## GitHub Workflow
- Issues/Projects used to break tasks down.
- PRs opened for each task and at least one peer review exchange.

## Lessons Learned and Future Work
- ...
