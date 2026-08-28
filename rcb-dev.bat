@echo off
REM rcb-dev.bat -- run RCB from this working tree (no gem install).
REM Resolves its own location, so it works from any clone and from any
REM cwd (put the repo root on PATH, or call it explicitly).
setlocal
set "DIR=%~dp0"
set "DIR=%DIR:~0,-1%"
ruby -I"%DIR%\rcb\lib" "%DIR%\rcb\exe\rcb" %*