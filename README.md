# Power Shell Scripts
Useful Powershell scripts





BackupRotateCopy.ps1   
--- 
A script put together from different sources.

It maintains a specified number of backups in the destination.
It creates a new directory with formatted date `$date = Get-Date -Format dddd.d.MMMM.yyyy`
It uses robocopy with progress bar to copy data into the `$date` directory, and writes a log file.
It sends an email with the log file as attachement when job is complete.


Usage:
--



Credits:
--
It uses `Copy-WithProgress` script from [here](https://keithga.wordpress.com/2014/06/23/copy-itemwithprogress/).


