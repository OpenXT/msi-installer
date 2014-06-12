Option explicit
Const procFilter = "Windowtitle eq Hardware Update Wizard"
Const timeout = 1000

Dim wshShell
Dim i
i = 1
Set wshShell =  WScript.CreateObject("WScript.Shell")
Do While i > 0
  wshShell.Exec("cmd.exe /c taskkill.exe /f /fi " & chr(34) & procFilter & chr(34))
  WScript.Sleep timeout
Loop
