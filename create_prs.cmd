@echo off
setlocal enableextensions

cd /d C:\Users\lenovo\Desktop\projets\devops

set OWNER=chiheb-slimani
set REPO=url-shortener-devops

if not defined GITHUB_TOKEN (
  if exist "%USERPROFILE%\.github_token" (
    set /p GITHUB_TOKEN=<"%USERPROFILE%\.github_token"
  )
)
if defined GITHUB_TOKEN (
  set "GITHUB_TOKEN=%GITHUB_TOKEN:"=%"
)
if not defined GITHUB_TOKEN (
  echo GITHUB_TOKEN is not set. Set it or place a token in %USERPROFILE%\.github_token
  exit /b 1
)

for /f "delims=" %%A in ('git status --porcelain') do (
  echo Working tree not clean. Commit or stash first.
  exit /b 1
)

git checkout main
git pull origin main

call :make_pr 01-scaffold "chore: repo scaffold and deps" "Task: repo structure and dependencies"
call :make_pr 02-api "feat: core API endpoints" "Task: FastAPI endpoints and validation"
call :make_pr 03-storage "feat: sqlite persistence" "Task: SQLite table and persistence wiring"
call :make_pr 04-observability "feat: metrics logs tracing" "Task: metrics, JSON logs, OpenTelemetry tracing"
call :make_pr 05-tests "test: add API tests" "Task: pytest coverage for core endpoints"
call :make_pr 06-docker "build: add Dockerfile" "Task: containerize the service"
call :make_pr 07-ci "ci: add tests and docker build" "Task: CI pipeline for PR and main"
call :make_pr 08-security "ci: add CodeQL and ZAP" "Task: SAST and DAST workflows"
call :make_pr 09-k8s "k8s: add deployment and service" "Task: Kubernetes manifests"
call :make_pr 10-docs "docs: README and REPORT template" "Task: documentation and report template"

git checkout main
git pull origin main
echo Done.
exit /b 0

:make_pr
set SLUG=%~1
set TITLE=%~2
set BODY=%~3
set BRANCH=pr/%SLUG%

git checkout -b %BRANCH%
if not exist pr-notes mkdir pr-notes
echo %TITLE%> pr-notes\%SLUG%.md
echo %BODY%>> pr-notes\%SLUG%.md

git add pr-notes\%SLUG%.md
git commit -m "%TITLE%"
git push -u origin %BRANCH%

> "%TEMP%\pr.json" echo { "title": "%TITLE%", "head": "%BRANCH%", "base": "main", "body": "%BODY%" }
curl -s -H "Authorization: Bearer %GITHUB_TOKEN%" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/%OWNER%/%REPO%/pulls -d @"%TEMP%\pr.json"

git checkout main
exit /b 0
