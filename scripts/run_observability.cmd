@echo off
setlocal enableextensions

cd /d %~dp0\..

set "PORT=18000"
set "BASE_URL=http://127.0.0.1:%PORT%"
set "DB_PATH=%TEMP%\urls.db"

python -m pip install -r requirements.txt
set PID=
for /f "tokens=2 delims==;" %%p in ('wmic process call create "python -m uvicorn app.main:app --host 127.0.0.1 --port %PORT%" ^| find "ProcessId"') do set PID=%%p
if defined PID set "PID=%PID: =%"
if not defined PID (
  echo Failed to start the API process.
  exit /b 1
)

set READY=0
for /l %%i in (1,1,15) do (
  for /f "delims=" %%s in ('curl -s -o nul -w "%%{http_code}" http://127.0.0.1:%PORT%/healthz') do (
    if "%%s"=="200" (
      set READY=1
      goto ready
    )
  )
  timeout /t 1 >nul
)
:ready
if not "%READY%"=="1" (
  echo API did not start in time.
  goto cleanup
)

curl -s -X POST http://127.0.0.1:%PORT%/shorten -H "Content-Type: application/json" -d "{\"url\":\"https://example.com\"}"
curl -s http://127.0.0.1:%PORT%/healthz
curl -s http://127.0.0.1:%PORT%/metrics > "%TEMP%\metrics.txt"
type "%TEMP%\metrics.txt"

:cleanup
if defined PID taskkill /pid %PID% /f >nul 2>nul
del "%TEMP%\metrics.txt" >nul 2>nul
