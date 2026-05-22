$ErrorActionPreference = 'Stop';
$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  softwareName  = 'cloudbase-init*'
  fileType      = 'MSI'
  silentArgs    = "/qn /norestart"
  validExitCodes= @(0, 3010, 1605, 1614, 1641)
}

$svc = Get-Service -Name 'cloudbase-init' -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne 'Stopped') {
  Stop-Service -Name 'cloudbase-init' -Force -ErrorAction SilentlyContinue
  $svc.WaitForStatus('Stopped', [TimeSpan]::FromMinutes(2))
}

$uninstalled = $false
[array]$key = Get-UninstallRegistryKey -SoftwareName $packageArgs['softwareName']

if ($key.Count -eq 1) {
  $key | % {
    $packageArgs['file'] = "$($_.UninstallString)"

    if ($packageArgs['fileType'] -eq 'MSI') {
      $packageArgs['silentArgs'] = "$($_.PSChildName) $($packageArgs['silentArgs'])"
      $packageArgs['file'] = ''
    }

    Uninstall-ChocolateyPackage @packageArgs
  }
} elseif ($key.Count -eq 0) {
  Write-Warning "$packageName has already been uninstalled by other means."
} elseif ($key.Count -gt 1) {
  Write-Warning "$($key.Count) matches found!"
  Write-Warning "To prevent accidental data loss, no programs will be uninstalled."
  Write-Warning "Please alert package maintainer the following keys were matched:"
  $key | % {Write-Warning "- $($_.DisplayName)"}
}

Remove-Item "$env:ChocolateyInstall\lib\$env:ChocolateyPackageName" -Recurse -Force -ErrorAction SilentlyContinue
