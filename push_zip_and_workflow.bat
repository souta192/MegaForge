@echo off
setlocal enabledelayedexpansion

REM === MegaForge One-shot: ZIP + Git push + Pages deploy ===
REM Requirements: Git, PowerShell, Windows 10+ (Compress-Archive), robocopy

REM ---- Settings (you can override REPO_URL via environment) ----
if not defined REPO_URL set "REPO_URL=https://github.com/souta192/MegaForge.git"
if not defined BRANCH set "BRANCH=main"
if not defined ZIP_NAME set "ZIP_NAME=source.zip"
if not defined GH_REPO_NAME set "GH_REPO_NAME=MegaForge"

echo ==== Checking prerequisites ====
where git >nul 2>nul || (echo ERROR: git not found & exit /b 1)
where powershell >nul 2>nul || (echo ERROR: PowerShell not found & exit /b 1)
where robocopy >nul 2>nul || (echo ERROR: robocopy not found & exit /b 1)

REM ---- Ensure next.config.mjs (only if missing) ----
if not exist "next.config.mjs" (
  echo Creating next.config.mjs (export mode) ...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "@'/** @type {import('next').NextConfig} */
const repoName = process.env.GH_PAGES_REPO || '%GH_REPO_NAME%';
const basePath = repoName ? `/${repoName}` : '';
const nextConfig = {
  output: 'export',
  images: { unoptimized: true },
  basePath,
  assetPrefix: basePath,
  trailingSlash: true,
  eslint: { ignoreDuringBuilds: true },
  typescript: { ignoreBuildErrors: true }
};
export default nextConfig;
'@ | Set-Content -Encoding UTF8 -NoNewline .\next.config.mjs" || (echo Failed to create next.config.mjs & exit /b 1)
)

REM ---- Create workflow file ----
echo Writing .github\workflows\pages-autodeploy.yml ...
mkdir ".github\workflows" 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "@'name: Auto Deploy Zip (source.zip or site.zip) to GitHub Pages
on:
  push:
    branches: [ %BRANCH% ]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: true
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Detect zip
        id: detect
        run: |
          ZIP=''
          [ -f site.zip ] && ZIP='site.zip'
          [ -z ""$ZIP"" ] && [ -f source.zip ] && ZIP='source.zip'
          [ -z ""$ZIP"" ] && ZIP=""$(ls -1 *.zip 2>/dev/null | head -n1 || true)""
          [ -z ""$ZIP"" ] && { echo 'no zip'; exit 1; }
          echo ""ZIP=$ZIP"" >> $GITHUB_ENV
      - name: If site.zip → unzip to out
        if: env.ZIP == 'site.zip'
        run: |
          mkdir -p out && unzip -q site.zip -d out
          [ -f out/index.html ] && cp out/index.html out/404.html || true
          touch out/.nojekyll
      - name: If source.zip → build & export
        if: env.ZIP != 'site.zip'
        run: |
          mkdir srcpkg && unzip -q ""$ZIP"" -d srcpkg
          cd srcpkg
          npm ci || npm i
          export GH_PAGES_REPO=%GH_REPO_NAME%
          npm run build
          npx next export || true
          cd ..
          mkdir out
          rsync -a srcpkg/out/ out/ || rsync -a srcpkg/.next/export/ out/ || exit 1
          [ -f out/index.html ] && cp out/index.html out/404.html || true
          touch out/.nojekyll
      - uses: actions/upload-pages-artifact@v3
        with:
          path: ./out
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
'@ | Set-Content -Encoding UTF8 -NoNewline .\.github\workflows\pages-autodeploy.yml" || (echo Failed to write workflow & exit /b 1)

REM ---- .gitignore (append if not contains) ----
if not exist ".gitignore" (
  >.gitignore echo node_modules/
  >>.gitignore echo .next/
  >>.gitignore echo out/
  >>.gitignore echo dist/
  >>.gitignore echo *.log
  >>.gitignore echo .env
)

REM ---- Create clean ZIP (exclude heavy/derived stuff) ----
set "TMP_DIR=__srcpkg_%RANDOM%%RANDOM%"
echo Creating clean source package in %TMP_DIR% ...
mkdir "%TMP_DIR%" 1>nul 2>nul
robocopy "." "%TMP_DIR%" /E /XD node_modules .git .next out dist build coverage .vercel .idea .vscode /XF *.log *.tmp *.DS_Store >nul
if errorlevel 8 (
  echo Robocopy error. Aborting.
  rmdir /s /q "%TMP_DIR%" 2>nul
  exit /b 1
)
echo Zipping to %ZIP_NAME% ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%TMP_DIR%\*' -DestinationPath '%ZIP_NAME%' -Force"
if errorlevel 1 (
  echo Failed to create %ZIP_NAME%.
  rmdir /s /q "%TMP_DIR%" 2>nul
  exit /b 1
)
rmdir /s /q "%TMP_DIR%" 2>nul
for %%F in ("%ZIP_NAME%") do echo Created: %%~fF (%%~zF bytes)

REM ---- Git init / commit / push ----
if not exist ".git" (
  echo Initializing git repo ...
  git init
)

REM default user config (skip if already set)
git config user.name  >nul 2>nul || git config user.name  "souta192"
git config user.email >nul 2>nul || git config user.email "you@example.com"

git add .
git commit -m "chore: add %ZIP_NAME% and Pages workflow" 2>nul
git branch -M %BRANCH%

REM Setup remote
for /f "tokens=2" %%R in ('git remote') do set HAVE_REMOTE=1
if not defined HAVE_REMOTE (
  git remote add origin "%REPO_URL%" 2>nul || git remote set-url origin "%REPO_URL%"
) else (
  git remote set-url origin "%REPO_URL%"
)

echo Pushing to %REPO_URL% (%BRANCH%) ...
git push -u origin %BRANCH%
if errorlevel 1 (
  echo.
  echo Push failed. Please ensure you have access and a credential helper configured.
  echo You can set REPO_URL to your fork via:  set REPO_URL=https://github.com/<you>/MegaForge.git
  exit /b 1
)

echo.
echo ✅ Done. GitHub Actions will build & publish to Pages shortly.
echo Repo: %REPO_URL%
echo Pages URL (Project Pages): https://souta192.github.io/%GH_REPO_NAME%/
exit /b 0
