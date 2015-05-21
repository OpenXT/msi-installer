#
# Copyright (c) 2014 Citrix Systems, Inc.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

$ScriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module $ScriptDir\..\..\BuildSupport\invoke.psm1

#Get parameters
$args | Foreach-Object {$argtable = @{}} {if ($_ -Match "(.*)=(.*)") {$argtable[$matches[1]] = $matches[2];}}
$BuildType = $argtable["BuildType"]
$CertName = $argtable["CertName"]
$VerString = $argtable["VerString"]
$signtool = $argtable["SignTool"]

Push-Location msi-installer\bootstrapper
makensis ("/DVERSION=" + $VerString) ./bootstrapper.nsi

# Codesigning
if ($BuildType -eq "Release")
{
    Write-Host "Signing setup.exe"
    Invoke-CommandChecked "Signing setup.exe" ($signtool+"\signtool.exe") sign /a /s my /n ('"'+$certname+'"') /t http://timestamp.verisign.com/scripts/timestamp.dll /d "OpenXT Tools Installer" setup.exe
}

Move-Item setup.exe ..\iso\windows\setup.exe -Force -Verbose
Pop-Location
 

