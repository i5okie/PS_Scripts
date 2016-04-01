# Backup Script, no rotate.
# Copy directories with progress
# Save Log
# Send Text message and email notifications
# references an simple Ruby twilio sms script
# Using Keith Garner's Copy-ItemWithProgress script.


# System Variables for Backup Procedure                                 #
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\#

 $date = Get-Date -Format dddd.d.MMMM.yyyy
 $env:Path += ";C:\scripts\HVBackup_1.0.1"

 
# Source                                                                #
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\#
  
 $serverBackup = "D:\LBStage\WindowsImageBackup"         
 
 
# Destination                                                           #
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\#

 # First stage. Create a copy of backup on local storage
 $DataDestination = "F:\BACKUP\$date"                 
 
 # Second stage. Backup to external drive.
 $destination = "\\td230\backup\$date"                
 
 
# Email Notification Variables                                          #
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\#

# Credentials
$secpasswd = ConvertTo-SecureString “<<smtp password>>” -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential (“<<smtp auth user email>>”, $secpasswd) 

# SMTP, Email Body
$smtp = "smtp.office365.com" 
$from = "<<from address>>" 
$to = "<<email recepient>>" 
$body = "This is an automatically generated message.<br>Your server backup has been successful.<br> Please remember to swap your hard drives when you return to the office for the continuing safety of your data<br><br>Best regards" 
$subject = "Backup Notification for $date"


# Send notification that backup has started                             #
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\#

# Send SMS via a Twilio API Ruby script
$message = "IBC SUPPORT GREMLIN: Backup has started. Please do not remove external drive! Thank you"
ruby C:\tools\util.rb $message


#########################################################################
# BEGIN Copy-ItemWithProgress script:                                   #

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
remove-item $RoboLog, $ScanLog}

# END Copy-ItemWithProgress script:                                     #
#########################################################################


# Make sure our destination directory structure is consistant           #
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\#

 # Check directory exists or create new one
  $path = test-Path $destination 
 if ($path -eq $true) { 
    write-Host "Directory Already exists" 
    } elseif ($path -eq $false) { 
       cd backup:\ 
       mkdir $date 
  }


# Begin first stage backup                                              #
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\#

 Copy-ItemWithProgress $serverBackup $DataDestination /e

 # Keep a log of our work for records and as email attachment
 $backup_log = Dir -Recurse $destination | out-File "$destination\backup_log.txt" 
 $attachment = "$destination\backup_log.txt" 


# Begin last stage backup                                               #
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\#

 # Copy to external drive to be taken off-site
 Copy-ItemWithProgress $DataDestination "G:\$date" /e      


# Send out our notification sms and email with attached log             #
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\#

# Notify of Backup Process END
$message = "SUPPORT GREMLIN: Backup has ended. You should receive an email shortly with detailed log. You may replace the external drive at your convenience!"
ruby C:\tools\util.rb $message

#Send an Email to User  
 Send-MailMessage -To $to -From $from -Attachments $attachment -SmtpServer "smtp.office365.com" -Credential $mycreds -UseSsl $subject -Port "587" -Body $body -BodyAsHtml 
