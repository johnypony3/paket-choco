<powershell>
$ErrorActionPreference = 'Stop'

winrm quickconfig -force
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in action=allow protocol=tcp localport=5985

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install git awscli -y --no-progress

# Match choco-bot environment (chocolatey-test-environment)
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -Name 'IsInstalled' -Value 0 -Force
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -Name 'IsInstalled' -Value 0 -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main' -Name 'DisableFirstRunCustomize' -Value 1 -PropertyType DWord -Force | Out-Null
Set-Service -Name wuauserv -StartupType Manual

choco feature enable  -n autouninstaller
choco feature enable  -n allowGlobalConfirmation
choco feature enable  -n logEnvironmentValues
choco feature disable -n showDownloadProgress

choco install kb2919442 --version 1.0.20160915 --skip-powershell -y
choco install kb2919355 --version 1.0.20160915 --skip-powershell -y
choco install kb2999226 --version 1.0.20181019 --skip-powershell -y
choco install kb3035131 --version 1.0.3         --skip-powershell -y
choco install kb3118401 --version 1.0.5         --skip-powershell -y
$env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')

$env:GITHUB_USERNAME = aws ssm get-parameter --region us-west-2 --name /paket-choco/github_username --query Parameter.Value --output text
$env:GITHUB_PASSWORD = aws ssm get-parameter --region us-west-2 --name /paket-choco/github_password --with-decryption --query Parameter.Value --output text
$env:CHOCO_KEY       = aws ssm get-parameter --region us-west-2 --name /paket-choco/choco_key --with-decryption --query Parameter.Value --output text
$winPassword         = aws ssm get-parameter --region us-west-2 --name /paket-choco/windows_password --with-decryption --query Parameter.Value --output text

net user Administrator $winPassword

git clone --branch ${branch} https://github.com/johnypony3/paket-choco.git C:\paket-choco

[Environment]::SetEnvironmentVariable('GITHUB_USERNAME', $env:GITHUB_USERNAME, 'Machine')
[Environment]::SetEnvironmentVariable('GITHUB_PASSWORD', $env:GITHUB_PASSWORD, 'Machine')
[Environment]::SetEnvironmentVariable('CHOCO_KEY',       $env:CHOCO_KEY,       'Machine')
</powershell>
