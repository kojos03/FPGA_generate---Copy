@echo off
setlocal ENABLEDELAYEDEXPANSION

REM Export thesis to Word (.docx) using Pandoc (no Docker required)
REM Prerequisites: Install Pandoc (https://pandoc.org/installing.html)

set ROOT=%~dp0
pushd "%ROOT%"

where pandoc >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Pandoc not found. Install from https://pandoc.org/installing.html or via winget: winget install --id JohnMacFarlane.Pandoc -e
  exit /b 1
)

if not exist output mkdir output

pandoc main.tex ^
  --from=latex ^
  --resource-path=".;chapters;appendices;figures" ^
  --toc ^
  --citeproc ^
  --bibliography=refs.bib ^
  -o output\thesis.docx

if errorlevel 1 (
  echo [ERROR] Pandoc conversion failed.
  exit /b 1
)

echo [OK] Exported Word document: output\thesis.docx
start "" output\thesis.docx

popd
exit /b 0
