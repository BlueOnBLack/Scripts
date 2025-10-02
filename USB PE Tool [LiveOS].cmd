
<# : standard way of doing hybrid batch + powershell scripts
@cls
@echo off

>nul chcp 437
SETLOCAL EnableDelayedExpansion
title USB PE Tool

set "args=" & set "args=%*"
if defined args set "args=!args:"=!"
if defined args set "args=!args:'=!"

if defined args if /i "A!args!" NEQ "A" (
  goto :Args_OK )

echo.
echo How to use
echo:

echo Install ISO Name [en_windows_11_consumer_editions_version_22h2_x64_dvd]
echo WIM Image Index  [^?] --- USER SELECTION ---
echo Partition Size   [^?] --- AUTO DETE SIZE ---
echo.
echo "%~nx0" "d:\Setup\en_windows_11_consumer_editions_version_22h2_x64_dvd.iso"
echo:

echo Install ISO Name [en_windows_11_consumer_editions_version_22h2_x64_dvd]
echo WIM Image Index  [^?] --- USER SELECTION ---
echo Partition Size   [120] GB
echo.
echo "%~nx0" "d:\Setup\en_windows_11_consumer_editions_version_22h2_x64_dvd.iso" 120
echo:

echo Install WIM Name [en_windows_11_consumer_editions_version_22h2_x64_dvd]
echo WIM Image Index  [9]
echo Partition Size   [80] GB
echo.
echo "%~nx0" "d:\Setup\en_windows_11_consumer_editions_version_22h2_x64_dvd\sources\install.wim" 9 80
echo:

exit /b

:Args_OK
set "fName="
cd /d "%~dp0"

for /f "tokens=*" %%$ in ('"2>nul where "%~n0""') do (
  set "fName=%%$"
  goto :skip
)

echo fail to get file path location ..
timeout 2 /nobreak
exit /b

:skip
set "rand=%temp%\%random%.ps1"
>nul 2>&1 copy /y "!fName!" "%rand%"
powershell -nop -ep bypass -f "%rand%" %*
>nul 2>&1 del /q "%rand%"
exit /b
#>

<# Powershell Code Start #>

# Powershell: loading a registry hive from file
# https://blog.redit.name/posts/2015/powershell-loading-registry-hive-from-file.html

Function Import-RegistryHive
{
    [CmdletBinding()]
    Param(
        [String][Parameter(Mandatory=$true)]$File,
        # check the registry key name is not an invalid format
        [String][Parameter(Mandatory=$true)][ValidatePattern('^(HKLM\\|HKCU\\)[a-zA-Z0-9- _\\]+$')]$Key,
        # check the PSDrive name does not include invalid characters
        [String][Parameter(Mandatory=$true)][ValidatePattern('^[^;~/\\\.\:]+$')]$Name
    )

    # check whether the drive name is available
    $TestDrive = Get-PSDrive -Name $Name -EA SilentlyContinue
    if ($TestDrive -ne $null)
    {
        throw [Management.Automation.SessionStateException] "A drive with the name '$Name' already exists."
    }

    $Process = Start-Process -FilePath "$env:WINDIR\system32\reg.exe" -ArgumentList "load $Key $File" -WindowStyle Hidden -PassThru -Wait

    if ($Process.ExitCode)
    {
        throw [Management.Automation.PSInvalidOperationException] "The registry hive '$File' failed to load. Verify the source path or target registry key."
    }

    try
    {
        # validate patten on $Name in the Params and the drive name check at the start make it very unlikely New-PSDrive will fail
        New-PSDrive -Name $Name -PSProvider Registry -Root $Key -Scope Global -EA Stop | Out-Null
    }
    catch
    {
        throw [Management.Automation.PSInvalidOperationException] "A critical error creating drive '$Name' has caused the registy key '$Key' to be left loaded, this must be unloaded manually."
    }
}

Function Remove-RegistryHive
{
    [CmdletBinding()]
    Param(
        [String][Parameter(Mandatory=$true)][ValidatePattern('^[^;~/\\\.\:]+$')]$Name
    )

    # set -ErrorAction Stop as we never want to proceed if the drive doesnt exist
    $Drive = Get-PSDrive -Name $Name -EA Stop
    # $Drive.Root is the path to the registry key, save this before the drive is removed
    $Key = $Drive.Root
	
	[GC]::Collect()
	[GC]::WaitForPendingFinalizers()

    # remove the drive, the only reason this should fail is if the reasource is busy
    Remove-PSDrive $Name -EA Stop

    $Process = Start-Process -FilePath "$env:WINDIR\system32\reg.exe" -ArgumentList "unload $Key" -WindowStyle Hidden -PassThru -Wait
    if ($Process.ExitCode)
    {
        # if "reg unload" fails due to the resource being busy, the drive gets added back to keep the original state
        New-PSDrive -Name $Name -PSProvider Registry -Root $Key -Scope Global -EA Stop | Out-Null
        throw [Management.Automation.PSInvalidOperationException] "The registry key '$Key' could not be unloaded, the key may still be in use."
    }
}

Function Live-OS-Install {
Param (
  [parameter(Mandatory=$true)]
  [STRING]
  $Wim,

  [INT]
  $Index,

  [INT]
  $Size
)

Begin {
  #nothing here
}

Process {

$wimlib = Get-Command -name "Wimlib-imagex.exe" -ErrorAction SilentlyContinue
if (!$wimlib -or (!(Test-Path($wimlib[0].Source)))) {
  Write-Host
  "error ### Wimlib-imagex.exe couldn't found ...."
  Write-Host
  return
}

if (!$wim.EndsWith('.iso') -And !$wim.EndsWith('.wim') -And !$wim.EndsWith('.esd') -And !$wim.EndsWith('.swm')) {
  Write-Host
  "error ### Bad file ???? ......."
  Write-Host
  return
}

$ISO = $null
if ($wim.EndsWith('.iso')) {
  $item = Get-ChildItem $wim -ErrorAction SilentlyContinue
  if ($item -and $item.Exists) {
    $ISO = $item.FullName
  }
  if (!$ISO) {
	Write-Host
    "error ### Bad file ???? ......."
    Write-Host
    return
  }
  
  Dismount-DiskImage -ImagePath $ISO -ErrorAction SilentlyContinue | Out-Null
  Mount-DiskImage -ImagePath $ISO -ErrorAction SilentlyContinue | Out-Null
  $image = Get-DiskImage $ISO
  if ($image) {
    $DriveLetter = (Get-DiskImage $ISO | Get-Volume).DriveLetter
  }  

  if (!$DriveLetter){
    Write-Host
    "error ### Bad ISO file ......."
    Write-Host
    return
  }

  $wim = $null
  if (Test-Path("$($DriveLetter):\Sources\install.wim")) {
    $wim = "$($DriveLetter):\Sources\install.wim"
  }
  if (Test-Path("$($DriveLetter):\Sources\install.swm")) {
    $wim = "$($DriveLetter):\Sources\install.swm"
  }
  if (Test-Path("$($DriveLetter):\Sources\install.esd")) {
    $wim = "$($DriveLetter):\Sources\install.esd"
  }
}

if (!($wim.EndsWith('.iso'))) {
  $item = $null
  $item = Get-ChildItem $wim -ErrorAction SilentlyContinue
  $wim = $null
  if ($item -and $item.Exists) {
    $wim = $item.FullName
  }
}

if ((!$wim) -or (!(Test-Path($wim)))) {
  Write-Host
  "error ### File not exist ......."
  Write-Host
  return
}

$nl =    [System.Environment]::NewLine
$array = cmd /c ""$wimlib[0].Source"" info $wim | Select-String "^Description:"
if (!$array -or ($array.length -eq 0)) {
  Write-Host
  "error ### index not found ......."
  Write-Host
  return
}

Write-Host
for ($i=0; $i -lt $array.length; $i++) {
  $edition = $array[$i].ToString().Split(':').Replace('    ','')[1]  
  if (@($i+1) -lt 10) {
    Write-Host "Index $($i+1)  :: $($edition)"
  }
  if (@($i+1) -ge 10) {
    Write-Host "Index $($i+1) :: $($edition)"
  }
}

write-host
if ($array.length -eq 1) {
  $Index = [INT](1)
}
if ($array.length -gt 1) {
  do {
    try {
	  $oKey = $null
	  if (!$Index) {
	    $selected = Read-Host -Prompt 'Select ID: '
	    $id = $selected -as [INT]
	  }
	  if ($Index) {
	    $oKey = $Index
		$Index = $null
	  }
	  1.. $array.length | % {
		if ($oKey -and ($_ -eq $oKey)) {
		  $Index = $_
		}
	    if (!$oKey -and ($_ -eq $id)) {
		  $Index = $_
		}
	  }
	}
	catch {
	}
  } While (!$Index)
}

if (!$Size) {
  $part = get-partition | ? DriveLetter -eq 'c'
  if ($part) {
    $disk = get-disk $part.DiskNumber
  }
  if ($disk) {
    $Size = [int]($disk.Size/1GB)
	$disk | get-partition | % { $Size = ($Size - ($_.size/1GB)) }
  }
  $Size = ($Size-1)
}

if (!$Size) {
  Write-Host
  "error ### disk size configuration can't be found ...."
  "          Make sure you have enougth space etc ......"
  Write-Host
  return
}

$DISKSIZE = ($Size * 1024 * 1024 * 1024)

if ($Size -le 30) {
  Write-Host
  "error ### minimum size is 30 GB ...."
  Write-Host
  return
}

Write-Host
"Index    is $($Index)"
"size     is $($DISKSIZE)"
"wim file is $($wim)"
Write-Host

Get-Service -Name "ShellHWDetection" | Stop-Service -force -ErrorAction SilentlyContinue
New-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name DisableAutoplay -PropertyType dword -Value 0x1 -Force -ErrorAction SilentlyContinue | Out-Null

$partition = get-partition | ? DriveLetter -eq 'c'
if ($partition) {
  "# Create Volume"
  $ltr = New-Partition -DiskNumber $partition.DiskNumber -Size $DISKSIZE -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}" -AssignDriveLetter
}

if ($ltr.DriveLetter) {
  "# Format Volume"
  $ProgressPreference = 'SilentlyContinue'    # Subsequent calls do not display UI.
  Format-Volume -DriveLetter $ltr.DriveLetter -FileSystem NTFS -Confirm -ErrorAction Continue | Out-Null
  $ProgressPreference = 'Continue'            # Subsequent calls do not display UI.
}

if (!(Test-Path("$($ltr.DriveLetter):\"))) {
  Write-Host
  "error ### Format drive failed ......."
  Write-Host
  return
}

"# Apply Image to Volume"
(cmd /c ""$wimlib[0].Source"" apply $wim $Index "$($ltr.DriveLetter):") *> $null

"# Update BCD Store"
(cmd /c bcdboot "$($ltr.DriveLetter):\windows" /l en-us /addlast) *> $null

Get-Service -Name "ShellHWDetection" | Start-Service -ErrorAction SilentlyContinue
New-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name DisableAutoplay -PropertyType dword -Value 0x0 -Force -ErrorAction SilentlyContinue | Out-Null

New-Item -Path "$($ltr.DriveLetter):\windows" -Name "Panther" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
Import-RegistryHive -File "$($ltr.DriveLetter):\windows\system32\config\SYSTEM" -Key "HKLM\TEMP_SYSTEM" -Name "SystemHive" -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path "SystemHive:\Setup" -Name UnattendFile -PropertyType string -Value 'c:\windows\Panther\AutoUnattend.xml' -Force -ErrorAction SilentlyContinue | Out-Null
Remove-RegistryHive -Name SystemHive | Out-Null

Write-Host
"$ ------------------------------------------- $"
"$ Untended file location set to:              $"
"$ $($ltr.DriveLetter):\windows\Panther\AutoUnattend.xml         $"
"$ ------------------------------------------- $"

# Force Dismount Image
if ($ISO -and (Test-path($ISO)) -and ($ISO.EndsWith('.iso',"CurrentCultureIgnoreCase"))) {
  Dismount-DiskImage -ImagePath $ISO -ErrorAction SilentlyContinue | Out-Null
}

Write-Host
"Done ..."
timeout 4
return
}
}

if ($args[0] -and !$args[1]) {
  
  # Case Wim file only
  # user choice wim index later
  # disk size will detect automaticly
  
  try {
    $wim  = $args[0].ToString()
    Live-OS-Install -Wim $wim
  }
  catch {
    write-host
    "error ### error occurred"
  }
}

if ($args[0] -and $args[1]) {
	
  if ($args[2]) {
    try {
      $wim   = $args[0].ToString()
      $Index = [int]($args[1])
      $Size  = [int]($args[2])
	  Live-OS-Install -Wim $wim -index $Index -size $Size
    }
    catch {
      write-host
      "error ### error occurred"
    }
  }
  
  # Case Wim file + size only
  # user choice wim index later
  
  if (!$args[2]) {
    try {
      $wim  = $args[0].ToString()
      $Size = [int]($args[1])
      Live-OS-Install -Wim $wim -size $Size
    }
    catch {
      write-host
      "error ### error occurred"
    }
  }
}

# Force Dismount Image
$ISO = $args[0].ToString()
if ($ISO -and (Test-path($ISO)) -and ($ISO.EndsWith('.iso',"CurrentCultureIgnoreCase"))) {
  Dismount-DiskImage -ImagePath $ISO -ErrorAction SilentlyContinue | Out-Null
}

# Restore Progress bar
$ProgressPreference = 'Continue'            # Subsequent calls do not display UI.

# Restore AutoPlay Service & Handler
Get-Service -Name "ShellHWDetection" | Start-Service -ErrorAction SilentlyContinue
New-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name DisableAutoplay -PropertyType dword -Value 0x0 -Force -ErrorAction SilentlyContinue | Out-Null

<# Powershell Code End #>