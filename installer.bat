@echo off
setlocal enabledelayedexpansion

REM Check for the correct number of arguments
if "%~1"=="" goto usage

set "FULL_PATH=%~1"
for %%F in ("%FULL_PATH%") do (
    set "TARGET_DIR=%%~dpF"
    set "FILENAME=%%~nF"
)

if "%FILENAME%"=="" (
    echo Error: Could not extract filename from path.
    exit /b 1
)

set "SCRNODES_BAT=%USERPROFILE%\scrnodes.bat"
set "HTML_FILE=%TARGET_DIR%\%FILENAME%.html"
set "SAVER_JS_FILE=%TARGET_DIR%\svr_%FILENAME%.js"

REM Ensure target directory exists
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

if exist "%HTML_FILE%" (
  if exist "%SAVER_JS_FILE%" (
    echo "Installation for %FILENAME% in %TARGET_DIR% already exists. Aborting."
    exit /b 0
  )
)

REM Determine the next available port
set "PORT=3000"
if exist "%SCRNODES_BAT%" (
    for /f "tokens=2" %%i in ('findstr /r "^REM [0-9][0-9]*" "%SCRNODES_BAT%"') do (
        set "LAST_PORT=%%i"
    )
    if defined LAST_PORT (
        set /a "PORT=LAST_PORT + 1"
    ) else (
        for /f "tokens=3 delims=: " %%i in ('findstr /r "echo.*:[0-9]*" "%SCRNODES_BAT%"') do (
            set "LAST_PORT=%%i"
        )
        if defined LAST_PORT (
            set /a "PORT=LAST_PORT + 1"
        )
    )
)


REM Create or update the scrnodes.bat script
if not exist "%SCRNODES_BAT%" (
    echo @echo off > "%SCRNODES_BAT%"
    echo. >> "%SCRNODES_BAT%"
    echo REM 3000 >> "%SCRNODES_BAT%"
    echo. >> "%SCRNODES_BAT%"
    echo cd /d "%TARGET_DIR%" ^& start "Node Server for %FILENAME%" /b node "%SAVER_JS_FILE%" >> "%SCRNODES_BAT%"
    echo. >> "%SCRNODES_BAT%"
    echo timeout /t 3 /nobreak ^>nul >> "%SCRNODES_BAT%"
    echo. >> "%SCRNODES_BAT%"
    echo echo. >> "%SCRNODES_BAT%"
    echo echo. >> "%SCRNODES_BAT%"
    echo echo. >> "%SCRNODES_BAT%"
    echo echo %FILENAME%: %PORT% >> "%SCRNODES_BAT%"
    echo echo. >> "%SCRNODES_BAT%"
    echo echo. >> "%SCRNODES_BAT%"
    echo echo. >> "%SCRNODES_BAT%"
) else (
    findstr /c:"cd /d \"%TARGET_DIR%\" ^& start \"Node Server for %FILENAME%\" /b node \"%SAVER_JS_FILE%\"" "%SCRNODES_BAT%" >nul
    if %errorlevel% neq 0 (
        REM Add the new port comment
        powershell -Command "(Get-Content -path '%SCRNODES_BAT%') + 'REM %PORT%' | Out-File -filepath '%SCRNODES_BAT%' -encoding ASCII"
        
        REM Add the new node service command before timeout
        powershell -Command "$content = Get-Content -path '%SCRNODES_BAT%'; $timeoutIndex = $content | Select-String -Pattern 'timeout' | Select -First 1 | ForEach-Object { $_.LineNumber - 1 }; $newContent = $content[0..($timeoutIndex-1)] + 'cd /d \"%TARGET_DIR%\" ^& start \"Node Server for %FILENAME%\" /b node \"%SAVER_JS_FILE%\"' + $content[$timeoutIndex..($content.Length-1)]; $newContent | Out-File -filepath '%SCRNODES_BAT%' -encoding ASCII"

        REM Add the new echo statement
        powershell -Command "$content = Get-Content -path '%SCRNODES_BAT%'; $lastEchoIndex = $content | Select-String -Pattern 'echo \".*:[0-9]*\"' | Select -Last 1 | ForEach-Object { $_.LineNumber - 1 }; $newContent = $content[0..$lastEchoIndex] + 'echo %FILENAME%: %PORT%' + $content[($lastEchoIndex+1)..($content.Length-1)]; $newContent | Out-File -filepath '%SCRNODES_BAT%' -encoding ASCII"
    )
)

if not exist "%HTML_FILE%" (
    REM Copy scribboleth.html to the target directory
    copy "%~dp0scribboleth.html" "%HTML_FILE%" >nul

    REM Update the node port in the new html file
    powershell -Command "(Get-Content -path '%HTML_FILE%') -replace 'let nodePort = 0;', 'let nodePort = %PORT%;' | Set-Content -path '%HTML_FILE%'"
    powershell -Command "(Get-Content -path '%HTML_FILE%') -replace 'let fileName = \"help\";', 'let fileName = \"%FILENAME%\";' | Set-Content -path '%HTML_FILE%'"
) else (
    REM Update the node port and file name in the existing html file
    powershell -Command "(Get-Content -path '%HTML_FILE%') -replace 'let nodePort = [0-9]*;', 'let nodePort = %PORT%;' | Set-Content -path '%HTML_FILE%'"
    powershell -Command "(Get-Content -path '%HTML_FILE%') -replace 'let fileName = \".*\";', 'let fileName = \"%FILENAME%\";' | Set-Content -path '%HTML_FILE%'"
)

if not exist "%SAVER_JS_FILE%" (
    REM Copy saver.js to the target directory
    copy "%~dp0saver.js" "%SAVER_JS_FILE%" >nul

    REM Update the file name and port in the new saver.js file
    powershell -Command "(Get-Content -path '%SAVER_JS_FILE%') -replace 'const FILE_PATH = \"./scribboleth.html\";', 'const FILE_PATH = \"./%FILENAME%.html\";' | Set-Content -path '%SAVER_JS_FILE%'"
    powershell -Command "(Get-Content -path '%SAVER_JS_FILE%') -replace 'const PORT = 3000;', 'const PORT = %PORT%;' | Set-Content -path '%SAVER_JS_FILE%'"
) else (
    REM Update the file name and port in the existing saver.js file
    powershell -Command "(Get-Content -path '%SAVER_JS_FILE%') -replace 'const FILE_PATH = \".*\";', 'const FILE_PATH = \"./%FILENAME%.html\";' | Set-Content -path '%SAVER_JS_FILE%'"
    powershell -Command "(Get-Content -path '%SAVER_JS_FILE%') -replace 'const PORT = [0-9]*;', 'const PORT = %PORT%;' | Set-Content -path '%SAVER_JS_FILE%'"
)


echo New scribboleth instance '%FILENAME%' created in '%TARGET_DIR%' on port %PORT%.
echo To start the node services, run: %SCRNODES_BAT%

cd "%TARGET_DIR%"
powershell -Command "Set-Content -Path 'package.json' -Value '{ \"dependencies\": { \"express\": \"^5.1.0\", \"body-parser\": \"^1.20.0\" } }' -Encoding ASCII"
npm install
goto:eof

:usage
echo Usage: %0 ^<path\to\filename_without_extension^>

exit /b 1
