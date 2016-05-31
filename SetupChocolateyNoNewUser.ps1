param([Parameter(Mandatory=$true)][string]$chocoPackages)
cls

New-Item "c:\jdchoco" -type Directory -force
$LogFile = "c:\jdchoco\JDScript.log"

$chocoPackages | Out-File $LogFile -Append

# Get username/password & machine name
$userName = "artifactInstaller"
[Reflection.Assembly]::LoadWithPartialName("System.Web") 
$password = $([System.Web.Security.Membership]::GeneratePassword(12,4))
$cn = [ADSI]"WinNT://$env:ComputerName"

# Create new user
$user = $cn.Create("User", $userName)
$user.SetPassword($password)
$user.SetInfo()
$user.description = "Choco artifact installer"
$user.SetInfo()

# Add user to the Administrators group
$group = [ADSI]"WinNT://$env:ComputerName/Administrators,group"
$group.add("WinNT://$env:ComputerName/$userName")

# Create pwd and new $creds for remoting
$secPassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\$($username)", $secPassword)

# Ensure that current process can run scripts. 
#"Enabling remoting" | Out-File $LogFile -Append
Enable-PSRemoting -Force -SkipNetworkProfileCheck

#"Changing ExecutionPolicy" | Out-File $LogFile -Append
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Install Choco under the artifact user's profile | TODO
#"Installing Chocolatey" | Out-File $LogFile -Append
$sb = { iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) }
Invoke-Command -ScriptBlock $sb -ComputerName $env:COMPUTERNAME -Credential $credential | Out-Null

#"Disalbing UAC" | Out-File $LogFile -Append
$sb = { Set-ItemProperty -path HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System -name EnableLua -value 0 }
Invoke-Command -ScriptBlock $sb -ComputerName $env:COMPUTERNAME -Credential $credential

#"Install Chocolatey Packages:" | Out-File $LogFile -Append
$chocoPackages.Split(";") | ForEach {
    $command = "cinst " + $_ + " -y -force" | Out-File $LogFile -Append
    $sb = [scriptblock]::Create("$command")
    Invoke-Command -ScriptBlock $sb -ArgumentList $chocoPackages -ComputerName $env:COMPUTERNAME -Credential $credential | Write-Output
}

#"Disable PSRemoting" | Out-File $LogFile -Append
Disable-PSRemoting -Force

# Delete the artifactInstaller user
$cn.Delete("User", $userName)

# Delete the artifactInstaller user profile
gwmi win32_userprofile | where { $_.LocalPath -like "*$userName*" } | foreach { $_.Delete() }
