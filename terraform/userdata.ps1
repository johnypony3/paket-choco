<powershell>
$ErrorActionPreference = 'Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install git awscli -y --no-progress
$env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')

$env:GITHUB_USERNAME = aws ssm get-parameter --region us-west-2 --name /paket-choco/github_username --query Parameter.Value --output text
$env:GITHUB_PASSWORD = aws ssm get-parameter --region us-west-2 --name /paket-choco/github_password --with-decryption --query Parameter.Value --output text
$env:CHOCO_KEY       = aws ssm get-parameter --region us-west-2 --name /paket-choco/choco_key --with-decryption --query Parameter.Value --output text
$winPassword         = aws ssm get-parameter --region us-west-2 --name /paket-choco/windows_password --with-decryption --query Parameter.Value --output text

net user Administrator $winPassword

$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$env:COMPUTERNAME`";CertificateThumbprint=`"$($cert.Thumbprint)`"}"
winrm set winrm/config/service/auth '@{Basic="true"}'
netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in action=allow protocol=tcp localport=5986

git clone --branch ${branch} https://github.com/johnypony3/paket-choco.git C:\paket-choco

[Environment]::SetEnvironmentVariable('GITHUB_USERNAME', $env:GITHUB_USERNAME, 'Machine')
[Environment]::SetEnvironmentVariable('GITHUB_PASSWORD', $env:GITHUB_PASSWORD, 'Machine')
[Environment]::SetEnvironmentVariable('CHOCO_KEY',       $env:CHOCO_KEY,       'Machine')
</powershell>
