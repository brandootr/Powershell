#import Remotedesktop services modules
Import-Module -Name remotedesktop
Import-Module -Name servermanager
#variables for RDS Servers
$webaccess = $env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN
$connectionBroker = $env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN
$rdsGateway = $env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN
$sessionhost = $env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN
$rdsGWDomain= 'rds.myimagine.com'
$CollectionName = 'Test RDS Collection'
$az_tenant=
$az_appid=
$az_appsecret=
$az_vaultname=
$az_sub = 
$User = $az_appid
$PWord = ConvertTo-SecureString -String $az_appsecret -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
$password = "123" | ConvertTo-SecureString -asPlainText -Force
$pfxPath=$env:USERPROFILE + '\desktop\osi.pfx'
$iissite='Default Web Site'
$certname='myimagine-com'

#Create RDS Deployment
New-RDSessionDeployment -ConnectionBroke $connectionBroker -SessionHost $sessionhost -WebAccessServer $webaccess 
#Create RDS Session Collection  Ignore any Group Policy Warnings.  These will appear if any RDS GP are Pre set
New-RDSessionCollection -CollectionName $CollectionName -SessionHost $sessionhost -ConnectionBroker $connectionBroker
#Install Choclatey if not already installed
if ((test-path 'C:\ProgramData\chocolatey') -eq $false) {Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}
#Configure RDS Gateway
Add-RDServer -Role RDS-GATEWAY -Server $rdsGateway -GatewayExternalFqdn $rdsGWDomain -ConnectionBroker $connectionBroker
Set-RDDeploymentGatewayConfiguration -GatewayMod Custom -GatewayExternalFqdn $rdsGWDomain -ConnectionBroker $connectionBroker -Force -BypassLocal $true -LogonMethod Password -UseCachedCredentials $true
Restart-Service -Name TSGateway -Force
#install Apps
choco install brave mobaxterm notepadplusplus tcping az.powershell vscode filezilla chocolateygui --confirm
#Create Remote Apps
New-RDRemoteApp -CollectionName $CollectionName -FilePath 'C:\Program Files (x86)\Mobatek\MobaXterm\MobaXterm.exe' -Alias 'MobaXTerm' -ShowInWebAccess $true -DisplayName 'MobaXTerm' -connectionbroker $connectionbroker
New-RDRemoteApp -CollectionName $CollectionName -FilePath '%windir%\system32\ServerManager.exe' -Alias 'ServerManager' -ShowInWebAccess $true -DisplayName 'Server Manager' -connectionbroker $connectionbroker
New-RDRemoteApp -CollectionName $CollectionName -FilePath 'C:\Program Files\Microsoft VS Code\Code.exe' -Alias 'vscode' -ShowInWebAccess $true -DisplayName 'VS Code' -connectionbroker $connectionbroker
New-RDRemoteApp -CollectionName $CollectionName -FilePath 'C:\Program Files\FileZilla FTP Client\filezilla.exe' -Alias 'FileZilla' -ShowInWebAccess $true -DisplayName 'FTP Client' -connectionbroker $connectionbroker
New-RDRemoteApp -CollectionName $CollectionName -FilePath 'C:\Program Files (x86)\Chocolatey GUI\ChocolateyGui.exe' -Alias 'ChocolateyGUI' -ShowInWebAccess $true -DisplayName 'Chocolately' -connectionbroker $connectionbroker
#Log in to Keyvault and get certificate
Import-Module Az.Accounts
    "Logging in to Azure..."
  Connect-AzAccount -Credential $Credential -Tenant $az_tenant -Subscription $az_sub  -ServicePrincipal
#Connect-AzAccount
$cert = Get-AzKeyVaultCertificate -VaultName $az_vaultname -Name $certname
$secret = Get-AzKeyVaultSecret -VaultName $az_vaultname -Name $cert.Name
$secretValueText = '';
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue)
try {
    $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}
$secretByte = [Convert]::FromBase64String($secretValueText)
$x509Cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
$x509Cert.Import($secretByte, "", "Exportable,PersistKeySet")
$type = [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx
$pfxFileByte = $x509Cert.Export($type, $password)

# Write to a file
[System.IO.File]::WriteAllBytes($pfxPath, $pfxFileByte)

#Import Certificate into Computer Cert Store

write-host "Imorting Certificate"
Import-PfxCertificate -CertStoreLocation Cert:\LocalMachine\My -FilePath $pfxpath -Password $password -Exportable
#Function to check critical services and start them if they are not running

function Check-Services {
write-host "Checking Services"
$services = @("RDMS","SessionEnv","Tssdis","TSGateway","W3SVC")
foreach ($service in $services){
$status=get-service -Name $service | select -ExpandProperty Status

if ($status -eq "Stopped")
{
    Start-Service -Name $service
    $status=get-service -Name $service | select -ExpandProperty Status
}
write-Host 'Service '  $service   ' is currently ' $status
}
}
#Restart-Service TSGateway -Force

#Bind Cert to all RDS Services and IIS

write-host "Applying Cert for RDPublishing"
Set-RDCertificate -Role RDPublishing -ImportPath $pfxPath -Password $password -ConnectionBroker $connectionBroker -Force
write-host "Applying Cert for Redirector"
Set-RDCertificate -Role RDRedirector -Password $password -ConnectionBroker $connectionBroker -Force
write-host "Applying Cert for RDGateway"
Set-RDCertificate -Role RDGateway -ImportPath $pfxPath -Password $password -ConnectionBroker $connectionBroker -Force
write-host "Applying Cert for RDWebAccess"
Set-RDCertificate -Role RDWebAccess -ImportPath $pfxPath -Password $password -ConnectionBroker $connectionBroker -Force

#One last Service Check

Check-Services
restart-service -Name W3SVC -Force
restart-service -Name rdms -Force
Restart-Service -Name SessionEnv -Force
Restart-Service -Name Tssdis -Force
Restart-Service -Name TSGateway -Force
