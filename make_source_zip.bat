@echo off
setlocal enabledelayedexpansion

REM === MegaForge: Create source.zip for GitHub Pages Action ===
REM This packs ONLY source files (no node_modules/.git/.next/out).
REM After packaging, it opens the GitHub upload page in your browser.

set "ZIP_NAME=source.zip"
set "TMP_DIR=__srcpkg_%RANDOM%%RANDOM%"
set "REPO_UPLOAD_URL=https://github.com/souta192/MegaForge/upload"

echo ==== Creating clean source package ====
echo Temp folder: %TMP_DIR%
mkdir "%TMP_DIR%" 1>nul 2>nul

REM Copy everything except common large/derived folders
robocopy "." "%TMP_DIR%" /E ^
  /XD node_modules .git .next out dist build coverage .vercel .idea .vscode ^
  /XF "*.log" "*.tmp" "*.DS_Store" >nul

if errorlevel 8 (
  echo Robocopy encountered an error. Aborting.
  rmdir /s /q "%TMP_DIR%" 2>nul
  exit /b 1
)

echo ==== Zipping to %ZIP_NAME% ====
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Compress-Archive -Path '%TMP_DIR%\*' -DestinationPath '%ZIP_NAME%' -Force" || (
    echo Failed to create %ZIP_NAME%.
    rmdir /s /q "%TMP_DIR%" 2>nul
    exit /b 1
)

REM Cleanup temp
rmdir /s /q "%TMP_DIR%" 2>nul

for %%F in ("%ZIP_NAME%") do (
  echo ✅ Created %%~fF ^(%%~zF bytes^)
)

echo.
echo Next: Upload %ZIP_NAME% to GitHub (main branch).
echo Opening: %REPO_UPLOAD_URL%
start "" "%REPO_UPLOAD_URL%"

echo Done.
exit /b 0
