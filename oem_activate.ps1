If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
Break
}

# Retrieve and set OEM activation key
$mykey = (Get-WmiObject -Query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
slmgr /ipk $mykey
