# Build thesis locally with XeLaTeX + BibTeX (no Docker)
# Prerequisites: Install MiKTeX (https://miktex.org/download)
# Run: Right-click this file > Run with PowerShell (or run from integrated terminal)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if (-not (Test-Path 'output')) { New-Item -ItemType Directory -Path 'output' | Out-Null }

if (-not (Get-Command xelatex -ErrorAction SilentlyContinue)) {
  Write-Error 'XeLaTeX not found. Install MiKTeX and reopen terminal.'
}

# First XeLaTeX pass
& xelatex -output-directory=output -interaction=nonstopmode -file-line-error main.tex

# BibTeX pass (inside output)
Push-Location output
& bibtex main
Pop-Location

# Second and third XeLaTeX passes
& xelatex -output-directory=output -interaction=nonstopmode -file-line-error main.tex
& xelatex -output-directory=output -interaction=nonstopmode -file-line-error main.tex

if (Test-Path 'output/main.pdf') {
  Write-Host '[OK] Built output/main.pdf'
  Start-Process 'output/main.pdf'
} else {
  Write-Error 'PDF not generated. Check output/main.log'
}
