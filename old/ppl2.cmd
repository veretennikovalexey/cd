@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ===========================================================================
rem  ppl2.cmd - auto commit + push (safe version of ppl.cmd)
rem
rem  Usage:  ppl2.cmd                 -> commit message "alex <date time>"
rem          ppl2.cmd "my message"    -> custom commit message
rem
rem  Differences from ppl.cmd:
rem    - stops on the first real error instead of blindly continuing
rem    - deletes .git\index.lock only when it is really stale
rem    - checks remote access before touching anything
rem    - pull --rebase --autostash (no accidental merge commits / divergence)
rem    - commits only when there is something to commit
rem    - retries push (GitHub 5xx / network blips)
rem    - sets user.name / user.email per repo, does not overwrite --global
rem ===========================================================================

set "REMOTE=origin"
set "BRANCH=main"
set "PUSH_RETRIES=3"
set "RETRY_DELAY=20"
set "GIT_USER=veretennikovalexey"
set "GIT_MAIL=raidex@yandex.ru"

rem ---- commit message ------------------------------------------------------
set "MSG=%~1"
if "!MSG!"=="" (
    for /f "tokens=1-2 delims=:" %%a in ("%TIME%") do set "HHMM=%%a:%%b"
    set "HHMM=!HHMM: =0!"
    set "MSG=alex %DATE% !HHMM!"
)

pushd "%~dp0." || (echo [ppl2] ERROR: cannot enter "%~dp0" & exit /b 1)
echo [ppl2] repo: %CD%

rem ---- 0. is this actually a git repo? -------------------------------------
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [ppl2] ERROR: not a git repository.
    goto :fail
)

rem ---- 1. stale index.lock -------------------------------------------------
if exist ".git\index.lock" (
    tasklist /FI "IMAGENAME eq git.exe" 2>nul | find /I "git.exe" >nul
    if errorlevel 1 (
        echo [ppl2] removing stale .git\index.lock
        del /q ".git\index.lock"
    ) else (
        echo [ppl2] ERROR: git.exe is running - the lock is NOT stale.
        echo        Wait for the other git process to finish, then run again.
        goto :fail
    )
)

rem ---- 2. identity (repo-local, global config untouched) -------------------
git config user.name  >nul 2>&1 || git config user.name  "%GIT_USER%"
git config user.email >nul 2>&1 || git config user.email "%GIT_MAIL%"

rem ---- 3. can we reach the remote at all? ----------------------------------
echo [ppl2] checking access to %REMOTE% ...
git ls-remote "%REMOTE%" >nul 2>&1
if errorlevel 1 (
    echo [ppl2] ERROR: cannot reach %REMOTE%. Nothing was changed.
    echo        Check the key:   ssh -T git@github.com
    echo        Check GitHub:    https://www.githubstatus.com/
    goto :fail
)

rem ---- 4. pull -------------------------------------------------------------
echo [ppl2] pulling ...
git pull --rebase --autostash "%REMOTE%" "%BRANCH%"
if errorlevel 1 (
    echo [ppl2] ERROR: pull/rebase failed - resolve it manually.
    git rebase --abort >nul 2>&1
    goto :fail
)

rem ---- 5. commit only if there is something --------------------------------
git add -A
if errorlevel 1 goto :fail
git diff --cached --quiet
if errorlevel 1 (
    echo [ppl2] commit: !MSG!
    git commit -m "!MSG!"
    if errorlevel 1 goto :fail
) else (
    echo [ppl2] nothing to commit
)

rem ---- 6. anything to push? ------------------------------------------------
set "AHEAD=1"
for /f %%n in ('git rev-list --count "%REMOTE%/%BRANCH%..HEAD" 2^>nul') do set "AHEAD=%%n"
if "!AHEAD!"=="0" (
    echo [ppl2] nothing to push - already up to date
    goto :done
)
echo [ppl2] commits to push: !AHEAD!

rem ---- 7. push with retries ------------------------------------------------
set /a ATTEMPT=0
:push
set /a ATTEMPT+=1
echo [ppl2] push attempt !ATTEMPT!/%PUSH_RETRIES% ...
git push "%REMOTE%" "%BRANCH%" && goto :done
if !ATTEMPT! GEQ %PUSH_RETRIES% (
    echo.
    echo [ppl2] ERROR: push failed %PUSH_RETRIES% times.
    echo        "Internal Server Error" / "remote rejected" = GitHub side,
    echo        your commit is safe locally - just run ppl2.cmd again later.
    goto :fail
)
echo [ppl2] retry in %RETRY_DELAY%s ...
rem  ping instead of timeout: timeout breaks under Git Bash / MinTTY
ping -n %RETRY_DELAY% -w 1000 127.0.0.1 >nul
goto :push

:done
echo [ppl2] OK
popd
endlocal
exit /b 0

:fail
echo [ppl2] FAILED
popd
endlocal
exit /b 1

rem pause
