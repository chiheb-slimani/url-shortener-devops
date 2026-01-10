@echo off
setlocal enableextensions

cd /d %~dp0\..

set "PORT=18000"
set "BASE_URL=http://127.0.0.1:%PORT%"
set "DB_PATH=%TEMP%\urls.db"

python -m pip install -r requirements.txt
start "" /b python -m uvicorn app.main:app --host 127.0.0.1 --port %PORT%

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
taskkill /f /im python.exe >nul 2>nul
del "%TEMP%\metrics.txt" >nul 2>nul
