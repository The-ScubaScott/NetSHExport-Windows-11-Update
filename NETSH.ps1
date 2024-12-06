<#
1. Create XML backup using NETSH.   Created in C:\Windows\Temp
2. Copy Script to run to C:\Windows\Temp the script will import the XML and launched by a Scheduled Task
3. Create schedule task to run at logon.   Script will be looking for OS version of WIN11 23H2 and will exit if false.  
4. If WIN11 23H2 is true it will import the XML file and remove the scheduled task
#Installation Successful: Windows successfully installed the following update: Windows 11, version 23H2
#>


###################################################
### Log Write #####################################
###################################################
Function Log-Write
{
	Param ([Parameter(Mandatory = $true)]
		[string]$LogPath,
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true)]
		[string]$LineValue)
	
	Process
	{
		$DateTime = Get-Date
		#Add-Content -Path $LogPath -Value $LineValue
		"$DateTime  -  $LineValue" | Out-File -FilePath $LogPath -Append
	}
}

$LogDir = "C:\Windows\Temp\NETSH_EXPORT"
If(!(test-path -PathType container $LogDir))
{
      New-Item -ItemType Directory -Path $LogDir
}

###################################################
### Log Setup #####################################
###################################################

$DateTime = Get-Date -Format yyyyMMdd_hhmmss
$LogDir = "C:\Windows\Temp\NETSH_Export"
$LogFileName = "NETSH_Export"
$LogFileType = "log"
$FullLogPath = $LogDir + "\" + $LogFileName + "_" + $DateTime + "." + $LogFileType
Log-Write -LogPath $FullLogPath -LineValue "Log has been configured"
###################################################

###################################################
#Export LAN Configuration to XML
$NICName = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.InterfaceAlias -like "*Ethernet*"} | Select-Object -ExpandProperty Name
$NICVar = $NICName
$NICName = '"'+$NICName+'"'
$Args = "lan export profile folder=$LogDir interface= $NICName"
Start-Process -FilePath "netsh" -ArgumentList $Args -wait
$Filename = $LogDir + "\" + $NICVar + ".xml"
$Filename = "C:\Windows\Temp\NETSH_Export\Ethernet 4.xml"

If (Test-Path -Path $Filename) {
    Log-Write -LogPath $FullLogPath -LineValue "XML file created: $Filename"
} else
{
    Log-Write -LogPath $FullLogPath -LineValue "XML file not created: $Filename"
}

###################################################



###################################################
#FileCopy
net use "\\**SERVERSHARE**\it\eus\applications\scripts\NETSH"
Copy-Item -Path "\\**SERVERSHARE**\it\eus\applications\scripts\netsh\NETSH_SchedTask.ps1" -Destination $LogDir
$PS1FileName= $LogDir + "\NETSH_SchedTask.PS1"
If (Test-Path $PS1Filename -PathType Leaf) {
    Log-Write -LogPath $FullLogPath -LineValue "PS1 File copied local"
}else
{
    Log-Write -LogPath $FullLogPath -LineValue "PS1 File not copied local"
}
###################################################


###################################################
#Create Scheduled Task
$taskname = "NETSH Import LAN Config"
$taskExists = Get-ScheduledTask | Where-Object { $_.TaskName -like $taskName }
if ($taskExists) {
    Log-Write -LogPath $FullLogPath -LineValue "Scheduled task already exists"
    } 
else 
    {
    $taskdescription = "Use NETSH to import the LAN Config"
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' `
        -Argument '-NoProfile -WindowStyle Hidden -ExecutionPolicy ByPass -File "C:\Windows\temp\NETSH_Export\NETSH_SchedTask.ps1"'
    $trigger =  New-ScheduledTaskTrigger -AtStartup 
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) 
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskname -Description $taskdescription -Settings $settings -User "System"
    }
###################################################
$taskExists = Get-ScheduledTask | Where-Object { $_.TaskName -like $taskName }
if ($taskExists) {
    Log-Write -LogPath $FullLogPath -LineValue "Scheduled task exists"
    }
else 
    {
    Log-Write -LogPath $FullLogPath -LineValue "Scheduled task was not created"
    }
