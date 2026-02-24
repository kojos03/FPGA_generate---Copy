@echo off
setlocal
cd /d %~dp0
if exist output (
  echo Deleting output folder...
  rmdir /s /q output
  mkdir output
  echo Clean done.
) else (
  mkdir output
)
exit /b 0
