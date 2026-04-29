$ErrorActionPreference = 'Stop';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$packageDir = Split-Path -parent $toolsDir

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'MSI'
  file          = "$packageDir\payload\CloudbaseInitSetup_x86.msi"
  file64        = "$packageDir\payload\CloudbaseInitSetup_x64.msi"
  softwareName  = 'cloudbase-init*'
  silentArgs    = "/qn /norestart /l*v `"$($env:SystemDrive)\Logs\$($env:ChocolateyPackageName).$($env:ChocolateyPackageVersion).MsiInstall.log`" INJECTMETADATAPASSWORD=TRUE USERGROUPS=Administrators RUN_SERVICE_AS_LOCAL_SYSTEM=1"
  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyInstallPackage @packageArgs
