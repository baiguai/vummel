@echo off
setlocal enabledelayedexpansion

REM Function to display usage
:usage
echo Usage: %0 ^<full_path_to_html_file^>
echo Example: %0 C:\Users\User\Documents\notes\mynotes.html
exit /b 1

REM Check for the correct number of arguments
if "%~1"=="" goto usage

set "FULL_PATH_HTML=%~1"
for %%F in ("%FULL_PATH_HTML%") do (
    set "TARGET_DIR=%%~dpF"
    set "FILENAME=%%~nF"
)

REM Remove trailing backslash from TARGET_DIR if present, unless it's just the root
if "%TARGET_DIR:~-1%"=="\" if not "%TARGET_DIR:~0,2%"=="\" set "TARGET_DIR=%TARGET_DIR:~0,-1%"

set "HTML_FILE=%TARGET_DIR%\%FILENAME%.html"
set "SAVER_JS_FILE=%TARGET_DIR%\svr_%FILENAME%.js"
set "SCRNODES_BAT=%USERPROFILE%\scrnodes.bat"
set "PACKAGE_JSON=%TARGET_DIR%\package.json"
set "NODE_MODULES_DIR=%TARGET_DIR%\node_modules"

echo Attempting to uninstall Scribboleth instance for: %HTML_FILE%
echo Associated saver script: %SAVER_JS_FILE%
echo This will also remove entries from: %SCRNODES_BAT%

choice /C YN /M "Are you sure you want to proceed?"
if errorlevel 2 goto :uninstallation_cancelled

echo.

REM --- Find the port from HTML file ---
set "PORT="
if exist "%HTML_FILE%" (
    for /f "tokens=*" %%L in ('powershell -Command "(Get-Content -Path '%HTML_FILE%') -match 'let nodePort = \d+;' | Select-String -Pattern '\d+' | ForEach-Object { $_.Matches.Value }"') do (
        set "PORT=%%L"
    )
)

if not defined PORT (
    echo Error: Could not find nodePort in %HTML_FILE%. Cannot proceed with scrnodes.bat cleanup.
    exit /b 1
) else (
    echo Identified port from HTML file: %PORT%
)

REM --- Remove files ---
echo Removing %HTML_FILE%...
if exist "%HTML_FILE%" del /f /q "%HTML_FILE%"

echo Removing %SAVER_JS_FILE%...
if exist "%SAVER_JS_FILE%" del /f /q "%SAVER_JS_FILE%"

echo Removing %PACKAGE_JSON%...
if exist "%PACKAGE_JSON%" del /f /q "%PACKAGE_JSON%"


REM --- Clean scrnodes.bat ---
if exist "%SCRNODES_BAT%" (
    echo Cleaning up %SCRNODES_BAT%...

    REM Escape special characters for PowerShell regex
    set "ESCAPED_TARGET_DIR=%TARGET_DIR:\=\%"
    set "ESCAPED_SAVER_JS_FILE=%SAVER_JS_FILE:\=\%"

    REM Remove REM %PORT% line
    if defined PORT (
        powershell -Command "(Get-Content -path '%SCRNODES_BAT%') | Where-Object { $_ -notmatch 'REM %PORT%' } | Set-Content -path '%SCRNODES_BAT%' -encoding ASCII"
    )

    REM Remove node service command line
    powershell -Command "(Get-Content -path '%SCRNODES_BAT%') | Where-Object { $_ -notmatch 'cd /d \"%ESCAPED_TARGET_DIR%\" \\^& start \"Node Server for %FILENAME%\" /b node \"%ESCAPED_SAVER_JS_FILE%\"' } | Set-Content -path '%SCRNODES_BAT%' -encoding ASCII"

    REM Remove echo %FILENAME%: %PORT% line
    if defined PORT (
        powershell -Command "(Get-Content -path '%SCRNODES_BAT%') | Where-Object { $_ -notmatch 'echo %FILENAME%: %PORT%' } | Set-Content -path '%SCRNODES_BAT%' -encoding ASCII"
    )

    REM Remove any resulting empty lines
    powershell -Command "(Get-Content -path '%SCRNODES_BAT%') | Where-Object { $_.Trim() -ne '' } | Set-Content -path '%SCRNODES_BAT%' -encoding ASCII"

    echo %SCRNODES_BAT% cleaned up.
) else (
    echo Warning: %SCRNODES_BAT% not found. Skipping scrnodes.bat cleanup.
)

echo.
echo --------------------------------------------------------
echo Uninstallation complete for %FILENAME%.
echo You may need to remove the Node.js modules folder if it's no longer needed: %NODE_MODULES_DIR%
echo --------------------------------------------------------

goto :eof

:uninstallation_cancelled
echo Uninstallation cancelled.
exit /b 0
