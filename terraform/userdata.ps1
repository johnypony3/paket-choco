<powershell>
$ErrorActionPreference = 'Stop'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install git -y --no-progress
$env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')

git clone --branch ${branch} https://github.com/johnypony3/paket-choco.git C:\paket-choco

$env:GITHUB_USERNAME      = "${github_username}"
$env:GITHUB_PASSWORD      = "${github_password}"
$env:CHOCO_KEY            = "${choco_key}"
$env:APPVEYOR_REPO_BRANCH = "main"

& C:\paket-choco\powershell-helpers\generate.ps1

Stop-Computer -Force
</powershell>
