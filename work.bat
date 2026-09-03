@echo off
cd /d "%~dp0"

where magick >nul 2>&1
if errorlevel 1 (
    echo ERROR: ImageMagick is not installed: counters cannot be created.
    pause
    exit /b 1
)

echo Creating wavy flags
powershell -NoProfile -ExecutionPolicy Bypass -File "flag.ps1"
echo Wavy flags created
echo.

echo Creating vertical flags
powershell -NoProfile -ExecutionPolicy Bypass -File "shield.ps1"
echo Vertical flags created
echo.

echo Creating flag icons
powershell -NoProfile -ExecutionPolicy Bypass -File "icon.ps1"
echo Flag icons created
echo.

echo Creating counters base
powershell -NoProfile -ExecutionPolicy Bypass -File "counters.ps1"
echo 
echo.

echo Putting national insignia on the counters
powershell -NoProfile -ExecutionPolicy Bypass -File "counters_2.ps1"
echo Counters created
echo.

:ASK_GIF
choice /C YN /N /M "Do you want to have gif files of the wavy flags (not used in HoI2)? [Y/N] "

if errorlevel 2 goto SKIP_GIF
if errorlevel 1 goto RUN_GIF

:RUN_GIF
echo.
echo Creating gif flags
powershell -NoProfile -ExecutionPolicy Bypass -File "gif.ps1"
echo Gif flags created
echo.
goto AFTER_GIF

:SKIP_GIF
echo
echo.

:AFTER_GIF
echo [EOF]
pause