@echo off
echo.
echo === PREPKING GIT SYNC ===
git pull origin main
echo.
git add .
git commit -m "Auto-sync %COMPUTERNAME% %DATE% %TIME:~0,8%"
git push origin main
echo.
echo Sync finished! You are up to date on both computers.
pause