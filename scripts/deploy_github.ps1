param(
  [string]$RepoName = ""  # set to project repo (e.g., "megaforge") for Project Pages
)

$ErrorActionPreference = "Stop"
Write-Host "==== GitHub Pages deploy (local) ===="

function Run($cmd) {
  Write-Host ">> $cmd"
  & cmd.exe /d /s /c $cmd
  if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
}

if ($RepoName) { $env:GH_PAGES_REPO = $RepoName }

try { Run "npm ls gh-pages" } catch { Run "npm i -D gh-pages" }

Run "npm run build"

$exportOk = $false
try { Run "npx next export -o out"; $exportOk = $true } catch { }
if (-not $exportOk) {
  Run "npx next export"
}

if (-not (Test-Path "out\index.html")) {
  if (Test-Path ".next\export\index.html") {
    Run "robocopy .next\export out /E"
  } else {
    throw "Export failed: out/index.html not found."
  }
}

node "scripts\postexport_fix_404.cjs"

Run "npx gh-pages -d out -b gh-pages"

Write-Host "✅ Deployed to GitHub Pages."
if ($RepoName) {
  Write-Host ("URL: https://<your-username>.github.io/" + $RepoName + "/")
} else {
  Write-Host "URL: https://<your-username>.github.io/"
}
