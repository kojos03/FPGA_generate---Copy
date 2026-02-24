# Export thesis to Word (.docx) using Pandoc
# Prerequisites: Install Pandoc (https://pandoc.org/installing.html)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
  Write-Error 'Pandoc not found. Install from https://pandoc.org/installing.html or via winget: winget install --id JohnMacFarlane.Pandoc -e'
}

if (-not (Test-Path 'output')) { New-Item -ItemType Directory -Path 'output' | Out-Null }

& pandoc 'main.tex' `
  --from=latex `
  --resource-path='.;chapters;appendices;figures' `
  --toc `
  --citeproc `
  --bibliography='refs.bib' `
  -o 'output/thesis.docx'

Write-Host '[OK] Exported Word document: output/thesis.docx'
Start-Process 'output/thesis.docx'
