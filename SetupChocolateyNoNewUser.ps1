param([Parameter(Mandatory=$true)][string]$chocoPackages)

cls

New-Item "c:\jdchoco" -type Directory -force
$LogFile = "c:\jdchoco\JDScript.log"
write-host $LogFile 

function IsAdministrator
{
    $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
    $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function IsUacEnabled
{
    (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System).EnableLua -ne 0
}


# Check to see if we are currently running "as Administrator"
if (!(IsAdministrator))
{
    "Not running as admin" | Out-File $LogFile -Append
   # We are running "as Administrator" - so change the title and background color to indicate this
   $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
   $Host.UI.RawUI.BackgroundColor = "DarkBlue"
   clear-host
}
else
{
    "Runnning as admin" | Out-File $LogFile -Append

   # We are not running "as Administrator" - so relaunch as administrator
   if (IsUacEnabled)
   {
        "UAC Enabled" | Out-File $LogFile -Append


        "Installing Choco" | Out-File $LogFile -Append
        # Grab the choco installation script
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

        [string[]]$argList = @('-NoProfile', '-NoExit', '-File', $MyInvocation.MyCommand.Path)
        $argList += $MyInvocation.BoundParameters.GetEnumerator() | Foreach {"-$($_.Key)", "$($_.Value)"}
        $argList += $MyInvocation.UnboundArguments
        Start-Process PowerShell.exe -Verb Runas -WorkingDirectory $pwd -ArgumentList $argList

        "Now running elevated" | Out-File $LogFile -Append
   }
   else
   {
        "UAC is not Enabled" | Out-File $LogFile -Append
   }
}
 
 Try
 {
    cinst $chocoPackages -y -f
 }
 Catch
 {
    "Error (caught)" | Out-File $LogFile -Append
    $_.Exception.Message | Out-File $LogFile -Append
    $_.Exception.ItemName | Out-File $LogFile -Append
 }

 "Finished" | Out-File $LogFile -Append   


