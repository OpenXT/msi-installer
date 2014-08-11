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

#Get parameters
$ScriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module $ScriptDir\..\..\BuildSupport\invoke.psm1

$args | Foreach-Object {$argtable = @{}} {if ($_ -Match "(.*)=(.*)") {$argtable[$matches[1]] = $matches[2];}}

$BuildTag = $argtable["BuildTag"]
$VerString = $argtable["VerString"]
$CertName = $argtable["CertName"]
$Company = $argtable["CompanyName"]

Push-Location msi-installer\installer
Invoke-CommandChecked "32 bit candle" ($env:WIX + "bin\candle.exe") installer.wxs -dPlatform="x86" ("-dCompany=" + $Company) ("-dPRODUCT_VERSION=" + $VerString) ("-dTAG=" + $BuildTag) -out XenClientTools.wixobj
Invoke-CommandChecked "32 bit light" ($env:WIX + "bin\light.exe") -sw1076 -ext WixUIExtension XenClientTools.wixobj -out XenClientTools.msi -cc cache -reusecab
Invoke-CommandChecked "64 bit candle" ($env:WIX + "bin\candle.exe") installer.wxs -dPlatform="x64" ("-dCompany=" + $Company) ("-dPRODUCT_VERSION=" + $VerString) ("-dTAG=" + $BuildTag) -out XenClientTools64.wixobj
Invoke-CommandChecked "64 bit light" ($env:WIX + "bin\light.exe") -sw1076 -ext WixUIExtension XenClientTools64.wixobj -out XenClientTools64.msi -cc cache -reusecab
Invoke-CommandChecked "sign 32 bit MSI" signtool.exe sign /a /s my /n $CertName /t http://timestamp.verisign.com/scripts/timestamp.dll /d "$Company XenClient Tools Installer" XenClientTools.msi
Invoke-CommandChecked "sign 64 bit MSI" signtool.exe sign /a /s my /n $CertName /t http://timestamp.verisign.com/scripts/timestamp.dll /d "$Company XenClient Tools Installer" XenClientTools64.msi

Pop-Location
