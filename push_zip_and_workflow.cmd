@echo off
setlocal enabledelayedexpansion

rem === Make source.zip, add workflow, git push to GitHub Pages ===
rem Requirements: Git (optional for push), PowerShell, Windows 10+ (Compress-Archive), robocopy

rem ---- Settings (override before run:  set REPO_URL=...) ----
if not defined REPO_URL set REPO_URL=https://github.com/souta192/MegaForge.git
if not defined BRANCH set BRANCH=main
if not defined ZIP_NAME set ZIP_NAME=source.zip
if not defined GH_REPO_NAME set GH_REPO_NAME=MegaForge

echo ==== Checking prerequisites ====
where powershell >nul 2>nul || (
  echo ERROR: PowerShell not found.
  exit /b 1
)
where robocopy >nul 2>nul || (
  echo ERROR: robocopy not found.
  exit /b 1
)

rem ---- Ensure next.config.mjs (create only if missing) ----
if not exist "next.config.mjs" (
  echo Creating next.config.mjs ...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$c = @'
/** @type {import('next').NextConfig} */
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
'@; Set-Content -Path 'next.config.mjs' -Encoding UTF8 -NoNewline -Value $c" || (
    echo Failed to create next.config.mjs
    exit /b 1
  )
)

rem ---- Write workflow (always overwrite to keep latest) ----
echo Writing .github\workflows\pages-autodeploy.yml ...
if not exist ".github\workflows" mkdir ".github\workflows" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$y = @'
name: Auto Deploy Zip (source.zip or site.zip) to GitHub Pages
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
          ZIP=\"\"
          [ -f site.zip ] && ZIP=\"site.zip\"
          [ -z \"$ZIP\" ] && [ -f source.zip ] && ZIP=\"source.zip\"
          [ -z \"$ZIP\" ] && ZIP=\"$(ls -1 *.zip 2>/dev/null | head -n1 || true)\"
          [ -z \"$ZIP\" ] && { echo \"no zip\"; exit 1; }
          echo \"ZIP=$ZIP\" >> $GITHUB_ENV
      - name: If site.zip -> unzip to out
        if: env.ZIP == 'site.zip'
        run: |
          mkdir -p out && unzip -q site.zip -d out
          [ -f out/index.html ] && cp out/index.html out/404.html || true
          touch out/.nojekyll
      - name: If source.zip -> build and export
        if: env.ZIP != 'site.zip'
        run: |
          mkdir srcpkg && unzip -q \"$ZIP\" -d srcpkg
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
'@; Set-Content -Path '.github/workflows/pages-autodeploy.yml' -Encoding UTF8 -NoNewline -Value $y" || (
    echo Failed to write workflow
    exit /b 1
  )

rem ---- Create clean source.zip (exclude heavy/derived stuff) ----
set "TMP_DIR=__srcpkg_%RANDOM%%RANDOM%"
echo Creating clean source package in %TMP_DIR% ...
mkdir "%TMP_DIR%" >nul 2>&1
robocopy "." "%TMP_DIR%" /E /XD node_modules .git .next out dist build coverage .vercel .idea .vscode /XF *.log *.tmp *.DS_Store >nul
if errorlevel 8 (
  echo Robocopy error. Aborting.
  rmdir /s /q "%TMP_DIR%" >nul 2>&1
  exit /b 1
)
echo Zipping to %ZIP_NAME% ...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Compress-Archive -Path '%TMP_DIR%\*' -DestinationPath '%ZIP_NAME%' -Force" || (
    echo Failed to create %ZIP_NAME%
    rmdir /s /q "%TMP_DIR%" >nul 2>&1
    exit /b 1
  )
rmdir /s /q "%TMP_DIR%" >nul 2>&1
for %%F in ("%ZIP_NAME%") do echo Created: %%~fF (%%~zF bytes)

rem ---- If Git is missing, just open upload page and exit ----
where git >nul 2>nul || (
  start "" https://github.com/souta192/MegaForge/upload
  echo Git not found. Opened browser to upload %ZIP_NAME%.
  exit /b 0
)

rem ---- Git init/commit/push ----
if not exist ".git" git init
git config user.name  >nul 2>nul || git config user.name  "souta192"
git config user.email >nul 2>nul || git config user.email "you@example.com"
git add .
git commit -m "chore: add %ZIP_NAME% and Pages workflow" 2>nul
git branch -M %BRANCH%

git remote get-url origin >nul 2>nul || git remote add origin "%REPO_URL%"
git remote set-url origin "%REPO_URL%"

echo Pushing to %REPO_URL% (%BRANCH%) ...
git push -u origin %BRANCH%
if errorlevel 1 (
  echo.
  echo Push failed. Configure credentials or set REPO_URL to your own repo:
  echo   set REPO_URL=https://github.com/あなた/MegaForge.git
  exit /b 1
)

echo.
echo ✅ Done. GitHub Actions will build & publish to Pages soon.
echo Pages URL (Project Pages): https://souta192.github.io/%GH_REPO_NAME%/
exit /b 0
