$packagesJsonPath = Join-Path $PSScriptRoot '..\packages.json'
$nuspecTemplate   = Join-Path $PSScriptRoot '..\packages\package.nuspec'
$toolsDir         = Join-Path $PSScriptRoot '..\packages'

$errors = @()

# Validate packages.json
try {
  $packages = Get-Content $packagesJsonPath -Raw | ConvertFrom-Json
  Write-Host "packages.json: valid JSON ($($packages.Count) packages)"
} catch {
  $errors += "packages.json: invalid JSON - $_"
}

$requiredFields = @('packageId','githubOrg','githubRepo','checksumType','versionFormat',
                    'title','authors','owners','licenseUrl','iconUrl','tags',
                    'packageSourceUrl','docsUrl','bugTrackerUrl','verificationHeader')

foreach ($pkg in $packages) {
  foreach ($field in $requiredFields) {
    if ([string]::IsNullOrEmpty($pkg.$field)) {
      $errors += "$($pkg.packageId): missing required field '$field'"
    }
  }
  Write-Host "$($pkg.packageId): required fields OK"
}

# Validate nuspec template
try {
  [xml](Get-Content $nuspecTemplate) | Out-Null
  Write-Host "package.nuspec: valid XML"
} catch {
  $errors += "package.nuspec: invalid XML - $_"
}

# Validate PowerShell script syntax
Get-ChildItem $PSScriptRoot -Filter '*.ps1' | ForEach-Object {
  $ast = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$ast, [ref]$parseErrors) | Out-Null
  if ($parseErrors.Count -gt 0) {
    $parseErrors | ForEach-Object { $errors += "$($_.File): $_" }
  } else {
    Write-Host "$($_.Name): syntax OK"
  }
}

# Validate install/uninstall scripts exist per package
foreach ($pkg in $packages) {
  $toolsPkg = Join-Path $toolsDir "$($pkg.packageId)\tools"
  foreach ($script in @('chocolateyInstall.ps1', 'chocolateyUninstall.ps1', 'LICENSE.txt')) {
    $path = Join-Path $toolsPkg $script
    if (!(Test-Path $path)) {
      $errors += "$($pkg.packageId): missing $script"
    }
  }
  Write-Host "$($pkg.packageId): tool files OK"
}

if ($errors.Count -gt 0) {
  Write-Host "`nValidation failed:"
  $errors | ForEach-Object { Write-Host "  - $_" }
  exit 1
}

Write-Host "`nAll validations passed."
