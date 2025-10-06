GITHUB PAGES READY PATCH

Steps:
1) Extract at project root and overwrite.
2) Project Pages (user.github.io/REPO):
   - PowerShell:  $env:GH_PAGES_REPO="REPO"
   - Bash:        export GH_PAGES_REPO=REPO
   - Or repo Settings → Actions → Variables → GH_PAGES_REPO=REPO
3) Local deploy:
   - PowerShell: scripts\deploy_github.ps1 -RepoName "REPO"
   - CMD:        scripts\deploy_github.bat
4) Or push to main; GitHub Actions will publish (see .github/workflows/pages.yml).
Notes:
- next.config.mjs uses GH_PAGES_REPO to set basePath/assetPrefix automatically.
- postexport_fix_404.cjs creates 404.html to fix deep-link refresh.
- public/.nojekyll prevents Jekyll from interfering with _next/ assets.
