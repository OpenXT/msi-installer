;
; Copyright (c) 2014 Citrix Systems, Inc.
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
; THE SOFTWARE.
;

!include "x64.nsh" ; Used to determine 32/64 bit machine
!include "FileFunc.nsh" ; Used to enable the GetParameters/GetOptions macros
!include "MUI.nsh" ; Gives the installer a UI

!insertmacro GetParameters ; Gets command line parameters
!insertmacro GetOptions ; Parses individual options from command line
!insertmacro GetSize ; Gets the size of a folder

; UI Settings
!define MUI_ICON ".\XenClient.ico"
!define MUI_UNICON ".\XenClient.ico"
!define MUI_LICENSEPAGE_CHECKBOX
!define MUI_WELCOMEFINISHPAGE_BITMAP ".\DialogInstall.bmp"
!define MUI_PAGE_HEADER_TEXT "OpenXT Tools Installer"
!define MUI_LICENSEPAGE_TEXT_TOP "Please Review the Terms below"

!define ProductName "OpenXT Tools"
!define CompanyName "OpenXT"
!define LegalCopyright ""
!define UrlAbout "http://openxt.org"
!define UrlUpdate "http://openxt.org"
!define FileDescription "Installer"

;Just for safety, define a default version of 1.0.0 build #1
!ifndef VERSION
!define VERSION "1.0.0.1"
!endif

; Execution level
RequestExecutionLevel admin

; Branding text on the installer
BrandingText "${ProductName}"

; The name of the installer
Name "${ProductName}"

;Version info for the file
VIAddVersionKey "ProductName" "${ProductName}"
VIAddVersionKey "CompanyName" "${CompanyName}"
VIAddVersionKey "FileDescription" "${FileDescription}"
VIAddVersionKey "LegalCopyright" "${LegalCopyright}"
VIAddVersionKey "FileVersion" "${VERSION}"
VIProductVersion "${VERSION}"

; UI Creation
!define MUI_PAGE_CUSTOMFUNCTION_PRE licenseSkip
!insertmacro MUI_PAGE_LICENSE "License.rtf"
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_LANGUAGE "English"

; Macro to stop the license page showing based on command line inputs
!macro hidePage hpParameter
  ${GetOptions} $R0 ${hpParameter} $R1 ; Try to read parameter into R1
  IfErrors +4 +1 ; See if read went ok...
  Pop $R1 ; We do not want to show the license, repair state & abort
  Pop $R0
  Abort
  ClearErrors ; Checking for the parameter created an error, clear errors flag
!macroend

; Function that decides whether to show the license page
Function licenseSkip
  ;Be caring about current state
  Push $R0
  Push $R1
  ${GetParameters} $R0 ; Copy params into R0
  
  # Check for parameters that should hide the license page
  !insertmacro hidePage '/uninstall'
  !insertmacro hidePage '/skipagreement'
  !insertmacro hidePage '/rmXenClientToolsMSI'
  !insertmacro hidePage '/rmXenSetupEXE'

  Pop $R1 ; Repair state
  Pop $R0
FunctionEnd

; $0 - location of manager, $1 - key counter, $2 - key name, $3 - key value, $4 - parameters
Function PrepareMachine

; Check to see if a manager is already installed on the machine
ReadRegStr $0 HKLM "Software\Citrix\XTPackageManagement" "manager" ; Attempt to read the registry key dictating where the package manager is
IfErrors prepareEnd +1

StrCpy $1 0 ; load 0th value first
StrCpy $4 ""

managerLoop:
  ClearErrors
  EnumRegValue $2 HKLM "Software\Citrix\XTPackageManagement" $1
  IfErrors done ; No more values
  IntOp $1 $1 + 1 ; Increment which value to read
  
  ; Only OK packages that we recognise, installers will handle upgrades
  StrCmp $2 "manager" managerLoop +1
  StrCmp $2 "XenClientToolsMSI" managerLoop +1
  StrCmp $2 "XenSetupEXE" managerLoop +1
  
  ; Key name was not recognised, read in the removal parameter
  ReadRegStr $3 HKLM "Software\Citrix\XTPackageManagement" $2
  StrCpy $4 "$4 $3"
  Goto managerLoop

done:
  StrCmp $4 "" +1 +3 ; Ask the manager to either remove just registry info or ask it to do that & remove the packages we don't recognise
  ExecWait '$0 /S /norestart /rmARP'
  Goto +2
  ExecWait '$0 /S /norestart$4'

  ExecWait 'del $0' ; Remove the old packages manager (Does not currently work, think this is a read only permissions setting)

prepareEnd: ; No manager, first time install
  ClearErrors ; There was an error flag set we should clear / it does not harm to clear an empty flag...
FunctionEnd

# Set the name of the installer
outfile "setup.exe"

# Set desktop as install directory
InstallDir $PROGRAMFILES\Citrix

#Variables to dictate what gets uninstalled
Var partial ; Doing a partial uninstall
Var msi ; Partial uninstall with /rmXenClientToolsMSI
Var xensetup ; Partial uninstall with /rmXenSetupEXE

# Create default section
section

  #We always want to put our files into the TEMP folder
  SetOutPath $TEMP\OpenXT ; Want to put our files in TEMP

  ###############################
  ### Command Line Checks #######
  ###############################
  
  #Asked to prevent reboot?
  SetRebootFlag true ; Assume we are going to reboot
  ${GetParameters} $R0 ; Copy params into R0
  ${GetOptions} $R0 '/norestart' $R1 ; Try to read /norestart flag into R1
  IfErrors +2 +1 ; Set reboot flag based on what we found
  SetRebootFlag false
  ClearErrors ; Checking for /norestart may have created an error as the flag was not there, clear the errors flag
  
  # Asked to do a full uninstall?
  ${GetOptions} $R0 '/uninstall' $R1 ; Try to read /uninstall flag into R1
  IfErrors +1 fullUninstall ; continue / Jump to uninstallation code
  ClearErrors ; Checking for /uninstall created an error as the flag was not there, clear the errors flag
  
  # Asked to simply remove our ARP info?
  ${GetOptions} $R0 '/rmARP' $R1 ; Try to read /rmARP flag into R1
  IfErrors +1 removeARP ; continue / Jump to ARP removal code
  ClearErrors ; Checking for /rmARP created an error as the flag was not there, clear the errors flag
  
  ###############################
  ### Partial Uninstall Checks ##
  ###############################
  StrCpy $partial 0 ; Assume we are going to run as install mode
  
  #Check whether asked to remove XenClientTools.msi package
  ${GetOptions} $R0 '/rmXenClientToolsMSI' $R1 ; Try to read /rmXenClientToolsMSI flag into R1
  IfErrors +3 +1 ; If flag not found clear errors, else set that we want to do a partial uninstall
  StrCpy $msi 1 ; Set we want to remove MSI
  StrCpy $partial 1 ; Set we need to do a partial uninstall
  ClearErrors ; Checking for /rmXenClientToolsMSI created an error as the flag was not there, clear the errors flag
  
  #Check whether asked to remove XenSetup.exe package
  ${GetOptions} $R0 '/rmXenSetupEXE' $R1 ; Try to read /rmXenSetupEXE flag into R1
  IfErrors +3 +1 ; If flag not found clear errors, else set that we want to do a partial uninstall
  StrCpy $xensetup 1 ; Set we want to remove XenSetup.exe
  StrCpy $partial 1 ; Set we need to do a partial uninstall
  ClearErrors ; Checking for /rmXenSetupEXE created an error as the flag was not there, clear the errors flag
  
  #Finally, check whether we have been asked to perform a partial uninstall and do it if needed
  IntCmp $partial 1 partialUninstall
  
  ###############################
  ### Install Mode ##############
  ###############################
    
  DotNetOK:
    Call PrepareMachine
  
    ; Determine machine bitage and run the suitable MSI installer
    ${If} ${RunningX64}
      File "..\installer\OpenXTTools64.msi"
      ExecWait 'msiexec /i "$TEMP\OpenXT\OpenXTTools64.msi" ARPSYSTEMCOMPONENT=1 /q /norestart /lvx* "$TEMP\OpenXT\log_OpenXTTools64.txt"'
    ${Else}
      File "..\installer\OpenXTTools.msi"
      ExecWait 'msiexec /i "$TEMP\OpenXT\OpenXTTools.msi" ARPSYSTEMCOMPONENT=1 /q /norestart /lvx* "$TEMP\OpenXT\log_OpenXTTools.txt"'
    ${EndIf}

    ; Run the drivers installer
    File ".\packages\xensetup.exe"
    ExecWait '"$TEMP\OpenXT\xensetup.exe" /S /norestart'
    
    ; Copy ourselves (setup.exe) to the installation directory
    System::Call 'kernel32::GetModuleFileNameA(i 0, t .R0, i 1024) i r1'
    CopyFiles /SILENT '$R0' $INSTDIR
    
    ; Create Add Remove Programs registry entries
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XenClient" "DisplayName" "OpenXT Tools" ; Name
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XenClient" "DisplayIcon" "$INSTDIR\setup.exe" ; Icon
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XenClient" "UninstallString" "$\"$INSTDIR\setup.exe$\" /uninstall" ; Uninstall command
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XenClient" "QuietUninstallString" "$\"$INSTDIR\setup.exe$\" /uninstall /S" ; Silent Uninstall
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XenClient" "EstimatedSize" "$0" ; Estimated size
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XenClient" "Publisher" "OpenXT" ; Publisher
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XenClient" "NoModify" "1"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XenClient" "NoRepair" "1"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XenClient" "DisplayVersion" ${VERSION}

    ;Create Package Management Entries
    WriteRegStr HKLM "Software\Citrix\XTPackageManagement" "manager" "$\"$INSTDIR\setup.exe$\"" ; Path to this executable as the packages manager
    WriteRegStr HKLM "Software\Citrix\XTPackageManagement" "XenClientToolsMSI" "/rmXenClientToolsMSI" ; Command to make the manager uninstall XenClientToolsMSI package
    WriteRegStr HKLM "Software\Citrix\XTPackageManagement" "XenSetupEXE" "/rmXenSetupEXE" ; Command to make the manager uninstall XenSetupEXE package
    
    Goto endOfCode ; Finish the install
  
  ###############################
  ### Uninstall Mode ############
  ###############################
  
  ; /uninstall flag passed, remove everything!
  fullUninstall:
    StrCpy $msi 1 ; Set flags to remove everything
    StrCpy $xensetup 1
    
    ; Set up some stuff to remove our installer post-reboot
    System::Call 'kernel32::GetModuleFileNameA(i 0, t .R0, i 1024) i r1'
    Delete /REBOOTOK $R0

    ; Remove all package management key entries
    DeleteRegKey HKLM "Software\Citrix\XTPackageManagement" ; Remove uninstall info from package management key
    
    SetOutPath $TEMP\OpenXT ; Restore outpath to TEMP
    
  ; We've been asked to remove certain packages only
  partialUninstall:
    ;Do this one first as you get Microsoft PnP windows popping up when the install should be finished...
    ;Essentially, use the MSI as a time buffer and hope that they all finish before the MSI's uninstall does
    IntCmp $xensetup 0 skipXenSetupUninstall ;Only uninstall xensetup.exe if told explicitly or told to do full uninstall
      File "..\bootstrapper\packages\xensetup.exe"
      ExecWait '"$TEMP\OpenXT\xensetup.exe" /S /norestart /uninstall'
      ; Decide whether we need to remove the package management key
      IntCmp $partial 0 +2
      DeleteRegKey HKLM "Software\Citrix\XTPackageManagement\XenSetupEXE" ; Remove uninstall info from package management key
    skipXenSetupUninstall:
    
    IntCmp $msi 0 skipMSIUninstall ;Only uninstall MSI if told explicitly or told to do full uninstall
      ${If} ${RunningX64}
        File "..\installer\OpenXTTools64.msi"
        ExecWait 'msiexec /uninstall "$TEMP\OpenXT\OpenXTTools64.msi" /q /norestart /lvx* "$TEMP\OpenXT\log_un_OpenXTTools64.txt"'
      ${Else}
        File "..\installer\OpenXTTools.msi"
        ExecWait 'msiexec /uninstall "$TEMP\OpenXT\OpenXTTools.msi" /q /norestart /lvx* "$TEMP\OpenXT\log_un_OpenXTTools.txt"'
      ${EndIf}
      ; Decide whether we need to remove the package management key
      IntCmp $partial 0 +2
      DeleteRegKey HKLM "Software\Citrix\XTPackageManagement\XenClientToolsMSI" ; Remove uninstall info from package management key
    skipMSIUninstall:

  ; We were asked to simply remove our ARP info
  removeARP:
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XenClient" ; Remove uninstall info from ARP (Add Remove Programs)
    DeleteRegKey /ifempty HKLM "Software\Citrix" ; Remove Citrix key only if it has no subkeys

  ; Final code bits common to all modes
  endOfCode:
    IfSilent +1 +3 ; Skip the next two lines if running in attended mode, else we may need to trigger a reboot
    IfRebootFlag +1 +2 ;If /norestart was specified, do not reboot automatically
    Reboot ; Running in silent mode without /norestart - Do a reboot!
  
sectionEnd
