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
$LogFileName = "NETSH_SchTask"
$LogFileType = "log"
$FullLogPath = $LogDir + "\" + $LogFileName + "_" + $DateTime + "." + $LogFileType
Log-Write -LogPath $FullLogPath -LineValue "Log has been configured"
###################################################

$info = [Environment]::OSVersion.Version
$Major = $info.Major
$OSVersion = [System.Version]::new($Major, $info.Minor, $info.Build)
if ($info.Build -le 22000) {
    Log-Write -LogPath $FullLogPath -LineValue "Windows 10 $OSVersion"
    exit
}

#start-service dot3svc
$service = Get-Service -Name "dot3svc"
if ($service.Status -ne "Running") {
    # Start the service
    Start-Service -Name "dot3svc"
    Log-Write -LogPath $FullLogPath -LineValue "DOT3SVC was not running. Start has been requested by script"
} else {
    Log-Write -LogPath $FullLogPath -LineValue "DOT3SVC was already running"
}

$NICName = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.InterfaceAlias -like "*Ethernet*"} | Select-Object -ExpandProperty Name
$NIC = $NICName
$NICName = '"'+$NICName+'"'
$fullpath = "$($LogDir)`\$($NIC).xml"
$Args = "lan add profile filename=`"$($fullpath)`" interface= $NICName"
Start-Process -FilePath "netsh" -ArgumentList $Args -Wait
Log-Write -LogPath $FullLogPath -LineValue "Executed NETSH with $Args"
Disable-NetAdapter -Name $NIC -Confirm:$False
Enable-NetAdapter -Name $NIC 
Log-Write -LogPath $FullLogPath -LineValue "Disabled/re-enabled NIC"

$taskname = "NETSH Import LAN Config"
$SchPath = “C:\Windows\System32\schtasks.exe”
$ARGS = @(
‘/DELETE’,
“/TN ““NETSH Import LAN Config”””,
“/f”
)

Start-Process -FilePath $SchPath -ArgumentList $ARGS  -Wait -ErrorAction SilentlyContinue

if ($(Get-ScheduledTask -TaskName $taskname -ErrorAction SilentlyContinue).TaskName -eq $taskname) { Unregister-ScheduledTask -TaskName $taskname -Confirm:$False }

$taskExists = Get-ScheduledTask | Where-Object { $_.TaskName -like $taskName }
if ($taskExists) {
    Log-Write -LogPath $FullLogPath -LineValue "Attempted removal of Scheduled Task, still exists"
    } 
else 
{
    Log-Write -LogPath $FullLogPath -LineValue "Scheduled removed"
    }