# BEGIN FUNCTIONS -----------------------------------------------------------

function Copy-ItemWithProgress {
<#
.SYNOPSIS
RoboCopy with PowerShell progress.

.DESCRIPTION
Performs file copy with RoboCopy. Output from RoboCopy is captured,
parsed, and returned as Powershell native status and progress.

.PARAMETER RobocopyArgs
List of arguments passed directly to Robocopy.
Must not conflict with defaults: /ndl /TEE /Bytes /NC /nfl /Log

.OUTPUTS
Returns an object with the status of final copy.
REMINDER: Any error level below 8 can be considered a success by RoboCopy.

.EXAMPLE
C:\PS> .\Copy-ItemWithProgress c:\Src d:\Dest

Copy the contents of the c:\Src directory to a directory d:\Dest
Without the /e or /mir switch, only files from the root of c:\src are copied.

.EXAMPLE
C:\PS> .\Copy-ItemWithProgress '"c:\Src Files"' d:\Dest /mir /xf *.log -Verbose

Copy the contents of the 'c:\Name with Space' directory to a directory d:\Dest
/mir and /XF parameters are passed to robocopy, and script is run verbose

.LINK

https://keithga.wordpress.com/2014/06/23/copy-itemwithprogress

.NOTES
By Keith S. Garner (KeithGa@KeithGa.com) - 6/23/2014
With inspiration by Trevor Sullivan @pcgeek86

#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true,ValueFromRemainingArguments=$true)] 
	[string[]] $RobocopyArgs
)

$ScanLog  = [IO.Path]::GetTempFileName()
$RoboLog  = [IO.Path]::GetTempFileName()
$ScanArgs = $RobocopyArgs + "/ndl /TEE /bytes /Log:$ScanLog /nfl /L".Split(" ")
$RoboArgs = $RobocopyArgs + "/ndl /TEE /bytes /Log:$RoboLog /NC".Split(" ")

# Launch Robocopy Processes
write-verbose ("Robocopy Scan:`n" + ($ScanArgs -join " "))
write-verbose ("Robocopy Full:`n" + ($RoboArgs -join " "))
$ScanRun = start-process robocopy -PassThru -WindowStyle Hidden -ArgumentList $ScanArgs
$RoboRun = start-process robocopy -PassThru -WindowStyle Hidden -ArgumentList $RoboArgs

# Parse Robocopy "Scan" pass
$ScanRun.WaitForExit()
$LogData = get-content $ScanLog
if ($ScanRun.ExitCode -ge 8)
{
	$LogData|out-string|Write-Error
	throw "Robocopy $($ScanRun.ExitCode)"
}
$FileSize = [regex]::Match($LogData[-4],".+:\s+(\d+)\s+(\d+)").Groups[2].Value
write-verbose ("Robocopy Bytes: $FileSize `n" +($LogData -join "`n"))

# Monitor Full RoboCopy
while (!$RoboRun.HasExited)
{
	$LogData = get-content $RoboLog
	$Files = $LogData -match "^\s*(\d+)\s+(\S+)"
    if ($Files -ne $Null )
    {
	    $copied = ($Files[0..($Files.Length-2)] | %{$_.Split("`t")[-2]} | Measure -sum).Sum
	    if ($LogData[-1] -match "(100|\d?\d\.\d)\%")
	    {
		    write-progress Copy -ParentID $RoboRun.ID -percentComplete $LogData[-1].Trim("% `t") $LogData[-1]
		    $Copied += $Files[-1].Split("`t")[-2] /100 * ($LogData[-1].Trim("% `t"))
	    }
	    else
	    {
		    write-progress Copy -ParentID $RoboRun.ID -Complete
	    }
	    write-progress ROBOCOPY -ID $RoboRun.ID -PercentComplete ($Copied/$FileSize*100) $Files[-1].Split("`t")[-1]
    }
}

# Parse full RoboCopy pass results, and cleanup
(get-content $RoboLog)[-11..-2] | out-string | Write-Verbose
[PSCustomObject]@{ ExitCode = $RoboRun.ExitCode }
remove-item $RoboLog, $ScanLog
}

function Rotation() {  
 #List all backup folders 
 $Backups = @(Get-ChildItem -Path $destination\*) 
 
 #Number of backups folders 
 $NbrBackups = $Backups.count 
 
 $i = 1 
  
 #Delete oldest backup folders 
 while ($NbrBackups -ge $maxbackup) 
 { 
  $Backups[$i] | Remove-Item -Force -Recurse -Confirm:$false 
  $NbrBackups -= 1 
  $i++ 
 } 
}  
# END FUNCTIONS -----------------------------------------------------------

####################################################################################################

### VARIABLES

# Sources
$mydata = "\\MYSERVER\ImportantStuff"


# Destination
$destination = "D:\BACKUP\$date"
$destinationdir = "D:\BACKUP"

## EMAIL STUFF

# build credentials for Office365 compatibility
$secpasswd = ConvertTo-SecureString “ubersecurepassword” -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential (“myaccount@domain.com”, $secpasswd) 

$smtp = "smtp.office365.com" 
$from = "support@domain.com"
$to = "joe@domain.com" 
$body = "Backup's done yo. Checkout the log file to see what got backed up." 
$subject = "Backup Notification for $date"

## OPTIONS
# how many backups to keep
$maxbackup = 2

# date format
$date = Get-Date -Format dddd.d.MMMM.yyyy


####################################################
# DO STUFF #

# Rotate backups, delete extra
Rotation

# Check if directory exists or create new one
$path = test-Path $destinationdir 
if ($path -eq $true) { 
  write-Host "Directory Already exists" 
  } elseif ($path -eq $false) { 
     cd $destinationdir 
     mkdir $date 
}


# commence backup
Copy-ItemWithProgress $mydata $Destination /e

# build backup log file
$backup_log = Dir -Recurse $destination | out-File "$destination\backup_log.txt" 
$attachment = "$destination\backup_log.txt" 


#Send an email to user  
 Send-MailMessage -To $to -From $from -Attachments $attachment -SmtpServer $smtp -Credential $mycreds -UseSsl $subject -Port "587" -Body $body -BodyAsHtml 

# all done
