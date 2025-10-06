\
@echo off
setlocal enabledelayedexpansion

REM Set GH_PAGES_REPO to repo name if using Project Pages (user.github.io/REPO)
REM set GH_PAGES_REPO=megaforge

where node >nul 2>nul || (echo Node.js not found & exit /b 1)
where git  >nul 2>nul || (echo git not found  & exit /b 1)

echo ==== GitHub Pages deploy (local) ====

call npm ls gh-pages >nul 2>nul || npm i -D gh-pages || goto :error

call npm run build || goto :error

npx next export -o out || npx next export || goto :error

if not exist out\index.html (
  if exist .next\export\index.html (
    robocopy .next\export out /E >nul
  ) else (
    echo Export failed: out\index.html not found.
    goto :error
  )
)

node scripts\postexport_fix_404.cjs || goto :error
npx gh-pages -d out -b gh-pages || goto :error

echo.
echo ✅ Deployed to GitHub Pages (branch: gh-pages)
echo If using Project Pages: https://<your-username>.github.io/%GH_PAGES_REPO%/
echo If using User/Org Pages: https://<your-username>.github.io/
exit /b 0

:error
echo.
echo ❌ Deployment failed.
exit /b 1
