@echo off
setlocal ENABLEDELAYEDEXPANSION

REM Build thesis locally with XeLaTeX + BibTeX (no Docker)
REM Prerequisites: Install MiKTeX (https://miktex.org/download)
REM Ensure xelatex.exe and bibtex.exe are on PATH (MiKTeX usually sets this automatically)

set ROOT=%~dp0
pushd "%ROOT%"

if not exist output mkdir output

where xelatex >nul 2>&1
if errorlevel 1 (
  echo [ERROR] XeLaTeX not found. Install MiKTeX and reopen terminal.
  exit /b 1
)

where bibtex >nul 2>&1
if errorlevel 1 (
  echo [WARN] BibTeX not found. MiKTeX can install it on the fly.
)

REM 1st XeLaTeX pass
xelatex -output-directory=output -interaction=nonstopmode -file-line-error main.tex
if errorlevel 1 (
  echo [ERROR] XeLaTeX pass 1 failed.
  exit /b 1
)

REM BibTeX pass (run inside output because bibtex dislikes paths)
pushd output
bibtex main
popd

REM 2nd and 3rd XeLaTeX passes
xelatex -output-directory=output -interaction=nonstopmode -file-line-error main.tex
xelatex -output-directory=output -interaction=nonstopmode -file-line-error main.tex

if exist output\main.pdf (
  echo [OK] Built output\main.pdf
  start "" output\main.pdf
) else (
  echo [ERROR] PDF not generated. Check logs in output\main.log
  exit /b 1
)

popd
exit /b 0
