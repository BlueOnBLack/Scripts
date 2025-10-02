
rem CMD file to add a VHD(x) boot object in BCD by MaloK
rem https://www.tenforums.com/virtualization/193557-cmd-file-add-vhd-x-boot-object-bcd.html

@cls
@echo off
>nul chcp 437
title VHD Helper Tool
SETLOCAL EnableDelayedExpansion

set "type=expandable"
set "part=%windir%\temp\part.txt"

rem Run as administrator, AveYo: ps\VBS version
>nul fltmc || ( set "_=call "%~dpfx0" %*"
	powershell -nop -c start cmd -args '/d/x/r',$env:_ -verb runas || (
	mshta vbscript:execute^("createobject(""shell.application"").shellexecute(""cmd"",""/d/x/r "" &createobject(""WScript.Shell"").Environment(""PROCESS"")(""_""),,""runas"",1)(window.close)"^))|| (
	cls & echo:& echo Script elavation failed& pause)
	exit )

set "args=" & set "args=%*"
if defined args set "args=!args:"=!"
if defined args set "args=!args:'=!"

if defined args if /i "A!args!" NEQ "A" (
  goto :Args_OK )

echo.
echo How to use
echo:

echo Drive      [D]
echo Full Name  [W.11]
echo VHD Size   [60] - 60GB
echo Boot Name  [W11 Test Version]
echo.
echo "%~nx0" "W11 Test Version" D "Hyper-v\W.11.Test.VM" 25
echo:

exit /b

:Args_OK

cls
echo:

for %%$ in (Name, DriveLetter, FullPath, Maxvhdsize) do (
  set "%%$=")
  
set "Name=%~1"
set "DriveLetter=%~2"
set "FullPath=%~3"
set "Maxvhdsize=%~4"

if not defined Name (set "err=Bad Args" & goto :error)
if not defined DriveLetter (set "err=Bad Args" & goto :error)
if not defined FullPath (set "err=Bad Args" & goto :error)
if not defined Maxvhdsize (set "err=Bad Args" & goto :error)

for %%$ in (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z) do (
  if /i "!DriveLetter!" == "%%$" (
    if exist %%$:\ (
	  goto :drive_found
    )
  )
)

(set "err=Bad Drive Letter" & goto :error)

:drive_found
if /i "!FullPath:~-4!" NEQ ".vhd" if /i "!FullPath:~-5!" NEQ ".vhdx" (
  set "FullPath=!FullPath!.vhdx"
)

if exist "%DriveLetter%:\%FullPath%" (
  echo "%DriveLetter%:\%FullPath%" --- already exist
  echo:
  goto :Drive_exist
)

(>nul 2>nul 3>nul echo. > "%DriveLetter%:\%FullPath%") && (>nul 2>nul del /q "%DriveLetter%:\%FullPath%" ) || (
  set "err=Bad file path"
  goto :error
)

set "d_Size="
set /a d_Size=(!Maxvhdsize!+1)

if not defined d_Size (
  set "err=Bad Drive Size"
  goto :error
)

REM if defined d_Size if !Maxvhdsize! == !d_Size! (
  REM set "err=Bad Drive Size"
  REM goto :error
REM )

echo "!Maxvhdsize!" | >nul 2>nul findstr /r [aA-zZ] && (
  set "err=Bad Drive Size"
  goto :error
)

set /a Maxvhdsize=(!Maxvhdsize!*1024)

 >%part% echo create vdisk file="%DriveLetter%:\%FullPath%" maximum=%Maxvhdsize% type=%type%
>>%part% echo select vdisk file="%DriveLetter%:\%FullPath%"
>>%part% echo attach vdisk
2>nul diskpart /s %part%
>nul 2>&1 del /q %part%
echo:

:Drive_exist
set "device_id="
for /f "tokens=2 delims={}" %%g in ('"2>nul bcdedit.exe /create /d "%Name%" /Device"') do (set device_id={%%g})
if not defined device_id (set "err=Cant find device ID" & goto :error)

set "guid="
bcdedit /set %device_id% device vhd=[%DriveLetter%:]"\%FullPath%"
for /f "tokens=2 delims={}" %%g in ('"2>nul bcdedit.exe /create /d "%Name%" /application osloader"') do (set guid={%%g})
if not defined guid (set "err=Cant find GUID" & goto :error)

bcdedit /set %guid% device vhd=[%DriveLetter%:]"\%FullPath%",%device_id%
bcdedit /set %guid% osdevice vhd=[%DriveLetter%:]"\%FullPath%",%device_id%
bcdedit /set %guid% systemroot \windows
bcdedit /set %guid% path \Windows\system32\winload.efi
bcdedit /set %guid% winpe no
bcdedit /set %guid% detecthal yes
bcdedit /set %guid% locale en-US

bcdedit /displayorder %guid% /addlast
bcdedit /set {bootmgr} displaybootmenu True
bcdedit /set {bootmgr} timeout 5

timeout 2 /nobreak
exit /b


:error
echo:
echo ERR :: %ERR%
echo:
exit /b