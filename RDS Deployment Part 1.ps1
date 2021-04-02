#import Remotedesktop services modules
Import-Module -Name remotedesktop
Import-Module -Name servermanager
#variables for RDS Servers
$webaccess = $env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN
$connectionBroker = $env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN
$rdsGateway = $env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN
$sessionhost = $env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN
#install Remote Desktop Services Roles
Install-WindowsFeature -Name Remote-Desktop-Services
Install-WindowsFeature -Name RDS-Connection-Broker
install-WindowsFeature -Name RDS-Licensing
Install-WindowsFeature -Name RDS-Web-Access -IncludeAllSubFeature
Install-WindowsFeature -Name RDS-Gateway -IncludeAllSubFeature
install-windowsfeature -Name RDS-RD-Server
Add-WindowsFeature NET-Framework-Core
Add-WindowsFeature NET-Framework-45-ASPNET
Add-WindowsFeature Web-Scripting-Tools
#Restart The Server and proceed to Part 2
Restart-Computer -ComputerName $sessionhost