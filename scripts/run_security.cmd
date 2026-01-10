@echo off
setlocal enableextensions

cd /d %~dp0\..

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

call :dispatch codeql.yaml "CodeQL SAST"
if errorlevel 1 exit /b 1
call :dispatch dast.yaml "ZAP DAST"
if errorlevel 1 exit /b 1
exit /b 0

:dispatch
set WF=%~1
set NAME=%~2
curl -s -f -X POST -H "Authorization: Bearer %GITHUB_TOKEN%" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/%OWNER%/%REPO%/actions/workflows/%WF%/dispatches -d "{\"ref\":\"main\"}" >nul
if errorlevel 1 (
  echo Failed to dispatch %NAME% workflow (%WF%).
  exit /b 1
)
echo Dispatched %NAME% workflow (%WF%).
exit /b 0
