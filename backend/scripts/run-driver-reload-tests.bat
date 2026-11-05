@echo off
setlocal
cd /d "%~dp0..\.."

echo ========================================================
echo  MEALGO - CHAY TU DONG TEST CASE: DRIVER RELOAD DON
echo ========================================================
echo Base URL: http://localhost:8080
echo File Collection: backend\postman\MealGo-Driver-Reload-Offers.postman_collection.json
echo.

call npx --yes newman run "backend\postman\MealGo-Driver-Reload-Offers.postman_collection.json" --env-var "baseUrl=http://localhost:8080" --reporters cli

if %ERRORLEVEL% equ 0 (
    echo.
    echo ========================================================
    echo  [SUCCESS] TAT CA TEST CASES RELOAD DON DEU PASS!
    echo ========================================================
) else (
    echo.
    echo ========================================================
    echo  [FAILURE] CO TEST CASE THAT BAI, VUI LONG KIEM TRA LOG!
    echo ========================================================
)

pause
