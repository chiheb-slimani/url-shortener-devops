@echo off
setlocal enableextensions

cd /d %~dp0\..

set "BASE_URL=http://127.0.0.1:8000"
set "DB_PATH=%TEMP%\urls.db"

python -m pip install -r requirements.txt
start "" /b python -m uvicorn app.main:app --host 127.0.0.1 --port 8000

set READY=0
for /l %%i in (1,1,15) do (
  curl -s http://127.0.0.1:8000/healthz >nul 2>nul && set READY=1 && goto ready
  timeout /t 1 >nul
)
:ready
if not "%READY%"=="1" (
  echo API did not start in time.
  goto cleanup
)

curl -s -X POST http://127.0.0.1:8000/shorten -H "Content-Type: application/json" -d "{\"url\":\"https://example.com\"}"
curl -s http://127.0.0.1:8000/healthz
curl -s http://127.0.0.1:8000/metrics > "%TEMP%\metrics.txt"
type "%TEMP%\metrics.txt"

:cleanup
set PID=
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8000" ^| findstr LISTENING') do (
  set PID=%%p
  goto stop
)
:stop
if defined PID taskkill /pid %PID% /f >nul 2>nul
del "%TEMP%\metrics.txt" >nul 2>nul
