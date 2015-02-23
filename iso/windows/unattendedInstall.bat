REM
REM Copyright (c) 2014 Citrix Systems, Inc.
REM 
REM Permission is hereby granted, free of charge, to any person obtaining a copy
REM of this software and associated documentation files (the "Software"), to deal
REM in the Software without restriction, including without limitation the rights
REM to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
REM copies of the Software, and to permit persons to whom the Software is
REM furnished to do so, subject to the following conditions:
REM 
REM The above copyright notice and this permission notice shall be included in
REM all copies or substantial portions of the Software.
REM 
REM THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
REM IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
REM FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
REM AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
REM LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
REM OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
REM THE SOFTWARE.
REM

@echo off
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v "Install"
if %ERRORLEVEL% NEQ 0 (
echo .NET 4.0 could not be found on this machine, please install .NET 4.0 and reboot before running this script
goto :EOF
)

echo Microsoft .NET 4.0 found
echo Administrative permissions are required. Checking permissions.
net session > nul 2>&1
if %ERRORLEVEL% == 0 (
echo Success: Permissions confirmed
) else (
echo Failure: Necessary permissions are not available
goto :EOF
)

ver | find " 5.1" > nul
IF %ERRORLEVEL% == 0 (set XP=1) ELSE (set XP=0)

IF %XP% == 0 (
certutil -addstore -enterprise -f "TrustedPublisher" "%~dp0SupportFiles\ToolsSigner.cer"
) ELSE (
start "HardwareWizardKiller" /min cscript "%~dp0SupportFiles\WizardKiller.vbs"
)

IF "%2"=="" (
"%~dp0setup.exe" /S /norestart
) ELSE (
"%~dp0setup.exe" /S /norestart /log %2
)

set RESTART=1
IF "%1" == "/DR" set RESTART=0
IF %ERRORLEVEL% NEQ 0 set RESTART=0

IF %XP% == 0 (
FOR /F "Tokens=3" %%I in ('certutil -dump "%~dp0SupportFiles\ToolsSigner.cer" ^| findstr "Serial Number"') do SET SERIAL=%%I
certutil -delstore -enterprise "TrustedPublisher" %SERIAL%
) ELSE (
taskkill.exe /f /fi "Windowtitle eq HardwareWizardKiller"
)

IF %RESTART% == 1 shutdown.exe /r /t 00
