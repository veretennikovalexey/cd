@echo off
REM ── Запускает локальный HTTP-сервер в этой папке и открывает index.html ──
REM Нужен Python 3 (https://python.org или Microsoft Store).
REM Сервер останется в отдельном чёрном окне — закрыть Ctrl+C или крестиком.

cd /d "%~dp0"

echo.
echo Starting local server on http://localhost:8000 ...
start "Chess Local Server" cmd /k "python -m http.server 8000"

echo Waiting 3 seconds for server to start...
timeout /t 3 /nobreak >nul

echo Opening http://localhost:8000/index.html ...
start "" "http://localhost:8000/index.html"
