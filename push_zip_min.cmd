@echo off
set ZIP_NAME=source.zip
set TMP_DIR=__srcpkg_%RANDOM%%RANDOM%
if not defined REPO_URL set REPO_URL=https://github.com/souta192/MegaForge.git
if not defined BRANCH set BRANCH=main

mkdir "%TMP_DIR%" >nul 2>&1
robocopy "." "%TMP_DIR%" /E /XD node_modules .git .next out dist build coverage .vercel .idea .vscode /XF *.log *.tmp *.DS_Store >nul
if errorlevel 8 exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%TMP_DIR%\*' -DestinationPath '%ZIP_NAME%' -Force"
if errorlevel 1 exit /b 1

rmdir /s /q "%TMP_DIR%" >nul 2>&1

where git >nul 2>&1 || exit /b 0
if not exist ".git" git init
git add .
git commit -m "add %ZIP_NAME%" 2>nul
git branch -M %BRANCH%
git remote get-url origin >nul 2>&1 || git remote add origin "%REPO_URL%"
git remote set-url origin "%REPO_URL%"
git push -u origin %BRANCH%
exit /b 0
