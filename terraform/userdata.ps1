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

git clone --branch ${branch} https://github.com/johnypony3/paket-choco.git C:\paket-choco

& C:\paket-choco\powershell-helpers\generate.ps1

Stop-Computer -Force
</powershell>
