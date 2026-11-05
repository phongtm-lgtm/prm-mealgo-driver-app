@echo off
setlocal
cd /d "%~dp0"

echo ========================================================
echo  MEALGO - TEST RUNNER: DRIVER RELOAD DON HANG (FREE-PICK)
echo ========================================================
echo Chon phuong thuc chay:
echo [1] Chay bang Newman CLI (Chay truc tiep Postman Collection voi report)
echo [2] Chay bang PowerShell Script (Tu dong toan bo, khong can cai Newman)
echo ========================================================
set /p choice="Nhap lua chon (1 hoac 2, mac dinh 1): "

if "%choice%"=="2" goto run_ps
goto run_newman

:run_newman
echo.
echo Dang khoi chay bang Newman...
call npx --yes newman run "backend\postman\MealGo-Driver-Reload-Offers.postman_collection.json" --env-var "baseUrl=http://localhost:8080" --reporters cli
goto end

:run_ps
echo.
echo Dang khoi chay bang PowerShell Script...
powershell -ExecutionPolicy Bypass -File "backend\scripts\test-driver-reload-flow.ps1"
goto end

:end
echo.
pause
