
rem Also Update Addins 		[1X Location]
rem Also Update Scripts 	[1X Location]
rem Also Update Windows 	[1X Location]


@cls
@echo off

MODE 140, 35
>nul chcp 437
title USB PE Tool
SETLOCAL EnableDelayedExpansion

rem Run as administrator, AveYo: ps\VBS version
>nul fltmc || ( set "_=call "%~dpfx0" %*"
	powershell -nop -c start cmd -args '/d/x/r',$env:_ -verb runas || (
	mshta vbscript:execute^("createobject(""shell.application"").shellexecute(""cmd"",""/d/x/r "" &createobject(""WScript.Shell"").Environment(""PROCESS"")(""_""),,""runas"",1)(window.close)"^))|| (
	cls & echo:& echo Script elavation failed& pause)
	exit )
	
cd /d "%~dp0"
Set "_Sys=NTFS"
set "_Scr=%windir%\temp\dps.txt"

set _T=
set _S=
set _B=
set _L=
set _K=
set _ISO=

set _T=%1
set _S=%2
set _B=%3
set _K=%4

set wimlib=
if exist "%~dp0wimlib-imagex.exe"     set wimlib="%~dp0wimlib-imagex.exe"
if exist "%windir%\wimlib-imagex.exe" set wimlib="%windir%\wimlib-imagex.exe"
if not exist !wimlib! (
	echo:
	echo wimlib .exe file is missing
	exit /b
)

pushd "%~dp0"
if exist "%~f0.cmd" 		set "0=%~dp0%~n0.cmd"
if not exist "%~f0.cmd" 	set "0=%windir%\%~n0.cmd"

if /i "!_B!" EQU "-PE" Set Live_M=true
if /i "!_K!" EQU "-PE" Set Live_M=true

if not defined _T goto :ShowMenu
if /i "!_T!" EQU "-USB" (set _T= & set _S=)
cls & echo.

echo Stop ShellHWDetection Service
>nul 2>&1 sc stop ShellHWDetection
>nul 2>&1 reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /f /v DisableAutoplay /t reg_dword /d 0x1

echo Define Drive Letter
if not defined _S (
	set "_S=!cd!"
	goto :NO_ARGS
)

set "_S=!_S:"=!"
for %%I in ("!_S!") do set "_S_=%%~dpnxI"
set "_S=!_S_!"

echo Verify variables
if not exist "!_S!" (
  echo.
  echo ERROR ##### File / Folder not exist
  echo.
  goto :WTF
)

set IS_IMAGE=

:: first check
set Pattern="^.*[.]wim$ ^.*[.]esd$ ^.*[.]swm$"
(echo !_S!|>nul 2>nul findstr /i /r %Pattern%) && set IS_IMAGE=true

:: second check
if not defined IS_IMAGE (
  set PS_CMD="[Regex]::IsMatch($env:_S, '.*(\.wim|\.esd|\.swm)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)"
  for /f "usebackq tokens=*" %%A in (`"%SingleNulV2% powershell -nop -c !PS_CMD!"`) do set "IS_IMAGE=%%A"
)

if defined IS_IMAGE if /i "!IS_IMAGE!" NEQ "TRUE" (
  set IS_IMAGE=
)

if defined IS_IMAGE if not defined Live_M (
  echo.
  echo ERROR ##### IMAGE can be selected using -PE args
  echo.
  goto :WTF
)

if defined IS_IMAGE if defined Live_M (
  (echo !_S!|>nul 2>nul findstr /i /r "^.*[.]swm$") && (set "ref=--ref="install*.swm"")
  goto :NO_ARGS
)

echo "!_S!" |>nul find /i ".iso" || (
	>nul pushd "!_S!" && (
		set "_S=!cd!"
		echo $$$$$ Using [!_S!] as Source
		goto :NO_ARGS
	) || (
		echo.
		echo ERROR ##### Not a Folder
		echo ERROR ##### Not a ISO file
		echo ERROR ##### Not a Image File
		echo.
		goto :WTF
	)
)

set _ISO='!_S!'
set "_CMD_=powershell -executionpolicy bypass -nop -c "Dismount-DiskImage -ImagePath !_ISO!; Mount-DiskImage -ImagePath !_ISO!;""
(>nul 2>&1 powershell -executionpolicy bypass -nop -c "!_CMD_!") || (
	echo.
	echo ERROR ##### Fail to mount iso file
	echo.
	goto :WTF
)

set "_CMD_=(Get-DiskImage !_ISO! | Get-Volume).DriveLetter"
>"%_Scr%" powershell -noprofile -executionpolicy bypass -command "!_CMD_!" || (
	echo.
	echo ERROR ##### Fail to get drive letter
	echo.
	goto :WTF
)

for /f "tokens=*" %%g in ('type "%_Scr%"') do set "_S=%%g:"
echo $$$$$ Using [!_ISO:'=!] as Source
echo $$$$$ Mount [!_ISO:'=!] to [!_S!]
!_S!

:NO_ARGS

set "_CHECK_="%2""
set "_CHECK_=!_CHECK_:""="!"
if /i !_CHECK_! EQU "" echo $$$$$ Using [!cd!] as Source
echo Check for local install

for %%i in (d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z) do (
	if /i "!_S!"=="%%i:" (
		set "_L=On"
		if not defined _T (goto :procced)
	)
	
	if /i "!_S!"=="%%i:\" (
		set "_L=On"
		set "_S=!_S:\=!"
		if not defined _T (goto :procced)
	)
)

IF Not defined _L (
	if "%1"=="" (
		echo.
		echo ERROR ##### Not A Removable Device
		echo.
		echo Please Pass Drive Latter of USB Drive
		echo "MakePortable E:"
		echo.
		goto :WTF
	)
)

echo Check User Input
if defined _T (

	for %%i in (d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z) do (
		if /i "!_T!"=="%%i:" (
			goto :procced
		)
		
		if /i "!_T!"=="%%i:\" (
			set _T=!_T:\=!
			goto :procced
		)
	)
)

set DiskID=
set "_PS_CMD_=Get-Disk ^| where ^{$_.Number -EQ !_T!^} ^| select Number"
for /f "tokens=1 skip=3 delims= " %%f in ('2^>nul powershell -nop -c "!_PS_CMD_!"') do if "%%f" EQU "!_T!" set "DiskID=%%f"
if defined DiskID goto:procced

echo.
echo ERROR ##### Bad User Input
echo.
goto :WTF

:procced
if defined IS_IMAGE if defined Live_M (
  goto :Stage_2
)

if not exist "!_S!\EFI" (
	echo.
	echo ERROR ##### Missing files.
	echo.
	goto :WTF
)

>nul 2>&1 pushd "!_S!"
>nul 2>&1 dir /b/ad *linux && Set "_Sys=FAT32"
>nul 2>&1 popd

:Stage_2
if defined DiskID (
	2>nul powershell -nop -c "get-disk !DiskID! | get-partition | select DriveLetter|format-list" | >nul find /i "DriveLetter : !_S:~0,1!" && (
		echo.
		echo ERROR ##### Same Drive
		echo.
		goto :WTF
	)
	goto :ID_BLAT_MAN
)

IF defined _L (
	if defined _T (
		if /i !_T! EQU !_S! (
			echo.
			echo ERROR ##### Same Drive
			echo.
			goto :WTF
		)
	)
)

IF Not defined _L (

	if not Exist "!_T!" (
		echo.
		echo ERROR ##### Drive Not Exist
		echo.
		goto :WTF
	)
	
	goto :ID_BLAT_MAN
)

IF defined _L (

	if not defined _T (
	
		goto :ID_BLAT_MAN
	)
	
	if defined _T (
	
		if not Exist "!_T!" (
			echo.
			echo ERROR ##### Drive Not Exist
			echo.
			goto :WTF
		)
		
		goto :ID_BLAT_MAN
	)
)

:ID_BLAT_MAN

IF Not defined _L (

	if defined Live_M (
		echo Format Usb Drive as FAT32\NADA\NTFS
		call :Smart_CLEAN !_t:~0,1!
	)
	
	if not defined Live_M (
		echo Format Usb Drive as !_Sys!
		call :CleanDrive  !_t:~0,1!
	)
	
	if not exist !_T! (
		echo.
		echo ERROR ##### Fail to Clean USB DOK
		echo.
		goto :WTF
	)
	
	if defined Live_M goto:X_M_NEXT
	echo Copy Files to USB Drive [!_T!]
	>nul 2>&1 xcopy "!cd!\" !_T! /e /q /g /h /r /y /c /i || (
		echo.
		echo ERROR ##### Fail to copy files to USB DOK
		echo.
		goto :WTF
	)
)

IF defined _L (
	if defined _T (
	
		if defined Live_M (
			echo Format Usb Drive as FAT32\NADA\NTFS
			call :Smart_CLEAN !_t:~0,1!
		)
		
		if not defined Live_M (
			echo Format Usb Drive as !_Sys!
			call :CleanDrive  !_t:~0,1!
		)
		
		if not exist !_T! (
			echo.
			echo ERROR ##### Fail to Clean USB DOK
			echo.
			goto :WTF
		)
		if defined Live_M goto:X_M_NEXT
		echo Copy Files to USB Drive [!_T!]
		>nul 2>&1 xcopy "!cd!\" !_T! /e /q /g /h /r /y /c /i || (
			echo.
			echo ERROR ##### Fail to copy files to USB DOK
			echo.
			goto :WTF
		)
	)
)

:X_M_NEXT

echo UEFI Patch

IF NOT defined _L (
	>nul 2>&1 bootsect /nt60 !_T! /force
)

IF defined _L (

	if defined _T (
		>nul 2>&1 bootsect /nt60 !_T! /force
	)
	
	if not defined _T (
		pushd %SystemDrive%
		>nul 2>&1 bootsect /nt60 "!_S!" /force
		popd
	)
)

set _BYPASS_=
if /i "%_B%" EQU "-TPM" set _BYPASS_=True
if /i "%_K%" EQU "-TPM" set _BYPASS_=True
if not defined _BYPASS_ goto:Ignore_Bypass

set _BYPASS_=
IF NOT defined _L set _BYPASS_=true
IF defined _L if defined _T set _BYPASS_=true
if not defined _BYPASS_ goto:Ignore_Bypass

pushd !_T!
call :TPM_Bypass
popd

:Ignore_Bypass
echo Start ShellHWDetection Service
>nul 2>&1 sc start ShellHWDetection
>nul 2>&1 reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /f /v DisableAutoplay /t reg_dword /d 0x0

if defined _ISO (
	echo Dismount ISO
	>nul 2>&1 powershell -noprofile -executionpolicy bypass -command "Dismount-DiskImage -ImagePath !_ISO!"
)

echo Done ...
echo:
pause
exit /b

:WTF
:WTF
:WTF

pushd %SystemDrive%
>nul 2>&1 sc start ShellHWDetection
>nul 2>&1 reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /f /v DisableAutoplay /t reg_dword /d 0x0
if defined _ISO >nul 2>&1 powershell -noprofile -executionpolicy bypass -command "Dismount-DiskImage -ImagePath !_ISO!"
echo Good bye :^)
goto :eof

:CleanDrive
:CleanDrive
:CleanDrive

set diskIndex=
set volumeIndex=
set targetDrive=%*
set EFI_PARTITION=U

set f_Letter=
for %%l in (o,n,m,l,k,j,i,h,g,f,e,d) do if not exist "%%l:\" set "f_Letter=%%l"

if     defined _ISO pushd %_S%
if not defined _ISO pushd %SystemDrive%
	
if defined DiskID (
	
	if not defined f_Letter (
		echo.
		echo ERROR ##### Fail to get a free letter
		echo.
		goto :WTF
	)
	
	set "_T=!f_Letter!:"
	set "targetDrive=!f_Letter!"
	set diskIndex=!DiskID!
	goto :Found_IDX_Y
)

>"%_Scr%" echo list volume
for /f "tokens=1,2,3 delims= " %%m in ('diskpart /s "%_Scr%"') do (
	if /i 'Volume' EQU '%%m' (	
		if /i '!targetDrive!' EQU '%%o' (
			REM echo Volume [%%n] Letter [%%o]
			set volumeIndex=%%n
		)		
	)
)

if defined volumeIndex (
	 >"%_Scr%" echo select volume !volumeIndex!
	>>"%_Scr%" echo list disk
	
	for /f "tokens=1,2,3 delims= " %%m in ('diskpart /s "%_Scr%"') do (
		if /i '*' EQU '%%m' (
			REM echo Select Disk [%%o]
			set diskIndex=%%o
		)
	)
)

:Found_IDX_Y
if not defined diskIndex (
	popd
	exit /b
)

 >"%_Scr%" echo select disk !diskIndex!
>>"%_Scr%" echo clean
>>"%_Scr%" echo clean
>nul 2>&1 diskpart /s "%_Scr%"

timeout 2>nul
 >"%_Scr%" echo select disk !diskIndex!
>>"%_Scr%" echo convert GPT
>>"%_Scr%" echo select partition 1
>>"%_Scr%" echo delete partition OVERRIDE
>nul 2>&1 diskpart /s "%_Scr%"

 >"%_Scr%" echo select disk !diskIndex!	
>>"%_Scr%" echo create partition primary id=c12a7328-f81f-11d2-ba4b-00a0c93ec93b size=500
>>"%_Scr%" echo create partition primary id=ebd0a0a2-b9e5-4433-87c0-68b6b72699c7
>nul 2>&1 diskpart /s "%_Scr%"

 >"%_Scr%" echo select disk !diskIndex!	
>>"%_Scr%" echo list partition
>>"%_Scr%" echo select partition 1
>>"%_Scr%" echo Format quick fs=fat32
>>"%_Scr%" echo ASSIGN LETTER=S
>nul 2>&1 diskpart /s "%_Scr%"

 >"%_Scr%" echo select disk !diskIndex!	
>>"%_Scr%" echo list partition
>>"%_Scr%" echo select partition 2
>>"%_Scr%" echo Format quick fs=!_Sys!
>>"%_Scr%" echo ASSIGN LETTER=!targetDrive!
>nul 2>&1 diskpart /s "%_Scr%"

2>nul powershell -nop -c "Get-Disk !diskIndex!|Get-Partition|Foreach {if ($_.DriveLetter) { $letter=$_.DriveLetter+':'; Remove-PartitionAccessPath -DiskNumber !diskIndex! -PartitionNumber $_.PartitionNumber -Accesspath $letter}}"
2>nul powershell -nop -c "Set-Partition -DiskNumber !diskIndex! -PartitionNumber 1 -NewDriveLetter !EFI_PARTITION!"
2>nul powershell -nop -c "Set-Partition -DiskNumber !diskIndex! -PartitionNumber 2 -NewDriveLetter !targetDrive!"
echo y | >nul 2>&1 format !EFI_PARTITION!: /q /x /FS:FAT32
echo y | >nul 2>&1 format !targetDrive!: /q /x /FS:NTFS

if not exist "!EFI_PARTITION!:\" 	echo ERROR ### Fail to get EFI  Partition INDEX info&echo:&exit /b
if not exist "!targetDrive!:\" 		echo ERROR ### Fail to get DATA Partition INDEX info&echo:&exit /b

>nul popd
>nul 2>nul md "!EFI_PARTITION!:\EFI"
>nul 2>nul xcopy "!cd!\EFI" "!EFI_PARTITION!:\EFI" /e /q /g /h /r /y /c /i

>nul 2>nul md "!EFI_PARTITION!:\BOOT"
>nul 2>nul xcopy "!cd!\BOOT" "!EFI_PARTITION!:\BOOT" /e /q /g /h /r /y /c /i

>nul 2>nul copy /y "!cd!\BOOTMGR*.*" "!EFI_PARTITION!:\"

echo:
Echo Remove old BCD store entries
>nul 2>nul bcdedit /store "!EFI_PARTITION!:\boot\bcd" /f /delete {default}
>nul 2>nul bcdedit /store "!EFI_PARTITION!:\boot\bcd" /f /delete {memdiag}
>nul 2>nul bcdedit /store "!EFI_PARTITION!:\EFI\Microsoft\boot\bcd" /f /delete {default}
>nul 2>nul bcdedit /store "!EFI_PARTITION!:\EFI\Microsoft\boot\bcd" /f /delete {memdiag}.

echo:

rem Credit RPO
rem https://forums.mydigitallife.net/threads/79199/

>nul pushd "!targetDrive!:\"

Echo Creating BCD entry for Windows Setup [boot\bcd]
set "BCDEDIT=bcdedit.exe /store "!EFI_PARTITION!:\boot\bcd" "

Echo Creating ramdisksdidevice entry...
for /f "tokens=2 delims={}" %%g in ('!BCDEDIT!  /create /device') do set ramdisk={%%g}
>nul 2>nul !BCDEDIT!  /set !ramdisk! description             "Windows Setup"
>nul 2>nul !BCDEDIT!  /set !ramdisk! ramdisksdidevice        partition=!EFI_PARTITION!:
>nul 2>nul !BCDEDIT!  /set !ramdisk! ramdisksdipath          \boot\boot.sdi

Echo Adding RAM Boot Windows Setup entry
for /f "tokens=2 delims={}" %%g in ('!BCDEDIT!  /create /application osloader') do set GUID={%%g}
>nul 2>nul !BCDEDIT!  /set !guid! device                  ramdisk=[!targetDrive!:]\sources\boot.wim,!ramdisk!
>nul 2>nul !BCDEDIT!  /set !guid! path                    \Windows\System32\Boot\winload.efi
>nul 2>nul !BCDEDIT!  /set !guid! description             "Windows Setup"
>nul 2>nul !BCDEDIT!  /set !guid! osdevice                ramdisk=[!targetDrive!:]\sources\boot.wim,!ramdisk!
>nul 2>nul !BCDEDIT!  /set !guid! systemroot              \Windows
>nul 2>nul !BCDEDIT!  /set !guid! detecthal               Yes
>nul 2>nul !BCDEDIT!  /set !guid! winpe                   Yes
>nul 2>nul !BCDEDIT!  /displayorder !guid! /addlast

echo:

Echo Creating BCD entry for Windows Setup [EFI\Microsoft\boot\bcd]
set "BCDEDIT=bcdedit.exe /store "!EFI_PARTITION!:\EFI\Microsoft\boot\bcd" "

Echo Creating ramdisksdidevice entry...
for /f "tokens=2 delims={}" %%g in ('!BCDEDIT!  /create /device') do set ramdisk={%%g}
>nul 2>nul !BCDEDIT!  /set !ramdisk! description             "Windows Setup"
>nul 2>nul !BCDEDIT!  /set !ramdisk! ramdisksdidevice        partition=!EFI_PARTITION!:
>nul 2>nul !BCDEDIT!  /set !ramdisk! ramdisksdipath          \boot\boot.sdi

Echo Adding RAM Boot Windows Setup entry
for /f "tokens=2 delims={}" %%g in ('!BCDEDIT!  /create /application osloader') do set GUID={%%g}
>nul 2>nul !BCDEDIT!  /set !guid! device                  ramdisk=[!targetDrive!:]\sources\boot.wim,!ramdisk!
>nul 2>nul !BCDEDIT!  /set !guid! path                    \Windows\System32\Boot\winload.efi
>nul 2>nul !BCDEDIT!  /set !guid! description             "Windows Setup"
>nul 2>nul !BCDEDIT!  /set !guid! osdevice                ramdisk=[!targetDrive!:]\sources\boot.wim,!ramdisk!
>nul 2>nul !BCDEDIT!  /set !guid! systemroot              \Windows
>nul 2>nul !BCDEDIT!  /set !guid! detecthal               Yes
>nul 2>nul !BCDEDIT!  /set !guid! winpe                   Yes
>nul 2>nul !BCDEDIT!  /displayorder !guid! /addlast

echo:

rem Credit freddie-o
rem https://forums.mydigitallife.net/threads/79199/

Echo Set legacy boot
>nul 2>nul bcdedit /store "!EFI_PARTITION!:\boot\bcd" /set '{default}' bootmenupolicy Legacy
>nul 2>nul bcdedit /store "!EFI_PARTITION!:\EFI\Microsoft\boot\bcd" /set '{default}' bootmenupolicy Legacy

echo Update Boot Sector
>nul 2>&1 bootsect /nt60 !EFI_PARTITION!: /force /mbr
>nul 2>&1 powershell -nop -c "Remove-PartitionAccessPath -DiskNumber !diskIndex! -PartitionNumber 1 -Accesspath !EFI_PARTITION!:"

echo:
popd
goto :eof

:Smart_CLEAN
:Smart_CLEAN
:Smart_CLEAN

if defined IS_IMAGE if defined Live_M (
  goto :Stage_3
)
pushd %_S%
:Stage_3
set /a count=0
if defined IS_IMAGE if defined Live_M set "wim_file=!_S!" & goto :Stage_3_
set "Ref="
set "wim_file="
if exist "sources\install.wim" set "wim_file=sources\install.wim"
if exist "sources\install.esd" set "wim_file=sources\install.esd"
if exist "sources\install.swm" set "wim_file=sources\install.swm" & (set "ref=--ref="install*.swm"")
if not defined wim_file echo:&echo ERROR ### Fail to get index info&echo:&goto:WTF

:Stage_3_

set SWM_LOC=
if defined ref (
  for /f %%# in ("!_S!") do (
    set "SWM_LOC=%%~dp#"
	if "!SWM_LOC:~-1!" NEQ "\" set "SWM_LOC=!SWM_LOC!\"
	(set "ref=--ref="!SWM_LOC!install*.swm"")
  )
)

set diskIndex=
set volumeIndex=
set targetDrive=%*
set EFI_PARTITION=U

set f_Letter=
for %%l in (o,n,m,l,k,j,i,h,g,f,e,d) do if not exist "%%l:\" set "f_Letter=%%l"

if defined DiskID (

	if not defined f_Letter (
		echo.
		echo ERROR ##### Fail to get a free letter
		echo.
		goto :WTF
	)
	
	set "_T=!f_Letter!:"
	set "targetDrive=!f_Letter!"
	set diskIndex=!DiskID!
	goto :Found_IDX
)

>"%_Scr%" echo list volume
for /f "tokens=1,2,3 delims= " %%m in ('diskpart /s "%_Scr%"') do (
	if /i 'Volume' EQU '%%m' (	
		if /i '!targetDrive!' EQU '%%o' (
			REM echo Volume [%%n] Letter [%%o]
			set volumeIndex=%%n
		)		
	)
)

if defined volumeIndex (
	 >"%_Scr%" echo select volume !volumeIndex!
	>>"%_Scr%" echo list disk
	
	for /f "tokens=1,2,3 delims= " %%m in ('diskpart /s "%_Scr%"') do (
		if /i '*' EQU '%%m' (
			REM echo Select Disk [%%o]
			set diskIndex=%%o
		)
	)
)

if not defined diskIndex goto:WTF

:Found_IDX

REM Clean partition a side.
 >"%_Scr%" echo select disk !diskIndex!
>>"%_Scr%" echo clean
>>"%_Scr%" echo clean
>nul 2>&1 diskpart /s "%_Scr%"

REM start Creating basic GPT partitions
timeout 2>nul
 >"%_Scr%" echo select disk !diskIndex!
>>"%_Scr%" echo convert GPT
>>"%_Scr%" echo select partition 1
>>"%_Scr%" echo delete partition OVERRIDE
>nul 2>&1 diskpart /s "%_Scr%"

 >"%_Scr%" echo select disk !diskIndex!
>>"%_Scr%" echo create partition primary size=100 id=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
>>"%_Scr%" echo create partition primary size=16  id=e3c9e316-0b5c-4db8-817d-f92df00215ae
>>"%_Scr%" echo Create Partition Primary          id=ebd0a0a2-b9e5-4433-87c0-68b6b72699c7
>nul 2>&1 diskpart /s "%_Scr%"

 >"%_Scr%" echo select disk !diskIndex!
>>"%_Scr%" echo select partition 1
>>"%_Scr%" echo FORMAT FS=FAT32 QUICK
>nul 2>&1 diskpart /s "%_Scr%"

 >"%_Scr%" echo select disk !diskIndex!
>>"%_Scr%" echo select partition 3
>>"%_Scr%" echo FORMAT FS=NTFS QUICK
>nul 2>&1 diskpart /s "%_Scr%"

:Clean_partition_LET
REM instead of fighting with this Stu* fuck auto mount 
REM use PS -> Remove-PartitionAccessPath COMMAND
2>nul powershell -nop -c "Get-Disk !diskIndex!|Get-Partition|Foreach {if ($_.DriveLetter) { $letter=$_.DriveLetter+':'; Remove-PartitionAccessPath -DiskNumber !diskIndex! -PartitionNumber $_.PartitionNumber -Accesspath $letter}}"

:Set EFI Partition
2>nul powershell -nop -c "Set-Partition -DiskNumber !diskIndex! -PartitionNumber 1 -NewDriveLetter !EFI_PARTITION!"
echo y | >nul 2>&1 format !EFI_PARTITION!: /q /x /FS:FAT32
if not exist "!EFI_PARTITION!:\" echo ERROR ### Fail to get EFI Partition INDEX info&echo:&exit /b

REM COntinue of no problem found
REM >nul 2>&1 xcopy EFI !EFI_PARTITION!:\EFI /e /q /g /h /r /y /c /i
REM >nul 2>&1 bcdedit /store !EFI_PARTITION!:\EFI\Microsoft\Boot\BCD /delete {default}

:Set DATA Partition

2>nul powershell -nop -c "Set-Partition -DiskNumber !diskIndex! -PartitionNumber 3 -NewDriveLetter !targetDrive!"
echo y | >nul 2>&1 format !targetDrive!: /q /x /FS:NTFS
if not exist !targetDrive!:\ echo ERROR ### Fail to get DATA Partition INDEX info&echo:&&exit /b

REM COntinue of no problem found
echo:

for /f "tokens=*" %%$ in ('"2>nul Dism /Get-ImageInfo /imagefile:"!wim_file!" | find /i "Name :""') do (
	set /a count +=1
	set "index_!count!=%%$"
	if !count! LSS 10 echo Index [#!count!] %%$
	if !count! GEQ 10 echo Index [!count!] %%$
)

:CHOICE WIM INDEX
set "Params="
if !count! LEQ 0 echo:&echo ERROR ### Fail to get index info&echo:&goto:WTF
FOR /L %%$ IN (1,1,!count!) do set "Params=!Params!,%%$"
if "!Params:~0,1!" EQU "," set "Params=!Params:~1!"
echo:
:Select_Wim_Index
set WimIndex=
set /p SelectedIndex=Select Edition index --^> 
for %%$ in (!Params!) do if "%%$" EQU "!SelectedIndex!" (
	set /a "WimIndex=%%$"
)
if not defined WimIndex goto:Select_Wim_Index
set "index_name=!index_%WimIndex%!"
set "index_name=!index_name:~7!"
echo Selected Index: !index_name!
!wimlib! apply "!wim_file!" !WimIndex! !targetDrive!:\ !ref!
REM Dism /apply-image /imagefile:"!wim_file!" /index:!WimIndex! /ApplyDir:!targetDrive!:\

:Update BCD STORE with the new OS
>nul 2>&1 bcdboot !targetDrive!:\windows /s !EFI_PARTITION!: /l en-US /f UEFI
>nul 2>&1 bcdedit -store !EFI_PARTITION!:\EFI\Microsoft\Boot\BCD -set {default} description "!index_name!"
>nul 2>&1 bootsect /nt60 !EFI_PARTITION!: /force /mbr
>nul 2>&1 powershell -nop -c "Remove-PartitionAccessPath -DiskNumber !diskIndex! -PartitionNumber 1 -Accesspath !EFI_PARTITION!:"

:set autountended xml file
>nul 2>&1 reg load HKLM\_SYSTEM "!targetDrive!:\windows\system32\config\SYSTEM"
>nul 2>&1 reg add "HKLM\_SYSTEM\Setup" /f /v UnattendFile /t reg_SZ /d "c:\windows\Panther\AutoUnattend.xml"
>nul 2>&1 reg unload HKLM\_SYSTEM
>nul 2>&1 md !targetDrive!:\windows\Panther

echo:
echo $ ------------------------------------------- $
echo $ Untended file location set to:              $
echo $ !targetDrive!:\windows\Panther\AutoUnattend.xml         $
echo $ ------------------------------------------- $

echo:
if defined IS_IMAGE if defined Live_M (
  goto :Stage_4
)
popd

:Stage_4
exit /b

rem Windows 11 Setup TPM Bypass - the non-convoluted way
rem https://forums.mydigitallife.net/threads/windows-11-setup-tpm-TPM-the-non-convoluted-way.84063/

:TPM_Bypass
:TPM_Bypass
:TPM_Bypass

if not exist sources\boot.wim (
	echo ERROR ##### SOURCES\BOOT.WIM NOT FOUND!
	echo.
	exit /b
)

set "wimimage="
set "tmpFile=%windir%\temp\result"

echo TPM Bypass by uwuowouwu420
>nul 2>&1 del /f /q sources\appraiserres.dll
set "fCD=%cd%"&if /i '!fCD:~-1!' EQU '\' set "fCD=!fCD:~0,-1!"
for %%k in (esd wim) do if exist "!fCD!\sources\install.%%k" set wimimage="!fCD!\sources\install.%%k"
if not defined wimimage (echo. & echo SOURCES\INSTALL.WIM NOT FOUND! & echo. & exit/b)
!wimlib! info !wimimage! --header | >!tmpFile! 2>&1 find /i "Image Count"
for /f "tokens=2 delims==" %%# in ('type !tmpFile!') do set "imagecount=%%#"
for /L %%i in (1,1,!imagecount!) do (>nul 2>&1 !wimlib! info !wimimage! %%i --image-property WINDOWS/INSTALLATIONTYPE=Server)
goto :eof

:ShowMenu
echo.
echo Usage:
echo Run from Removeable Drive  [ -USB ]
echo Run With Parameters  	   [ DISK ID / PART. LETTER ] [ ESD / WIM / SWM / ISO File / Setup Folder ] [-TPM ~ Optional] [-PE ~ Optional]
echo Run from Source Folder 	   [ Target Drive ]
echo.
echo -TPM --- Bypass the TPM 2.0 Requirement
echo -PE  --- WinPE Live From USB, 16GB DOK Or more IS needed
echo.
echo Available USB DISK
echo:

rem PS   : Get-Disk | where {$_.BusType -EQ 'USB'} | select FriendlyName,Model
rem WMIC : wmic path Win32_DiskDrive where (InterfaceType Like 'USB') get Model,caption
rem WMIC : wmic path Win32_DiskDrive where (InterfaceType Like "%%%%USB%%%%") get Model,caption

set "_PS_CMD_=Get-Disk | select Number,Size,FriendlyName | Foreach {$sz = $_.size/1GB; Write-Host 'Disk -'$_.Number', Total -'$sz 'GB , Name -' $_.FriendlyName}"
2>nul powershell -nop -c "!_PS_CMD_!"
exit /b