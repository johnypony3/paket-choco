$ErrorActionPreference = 'Stop';

$paketInfo = Invoke-RestMethod -Uri 'https://api.github.com/repos/fsprojects/Paket/releases'
$repoInfo = $paketInfo | where { $_.tag_name -eq $ENV:chocolateyPackageVersion }

$toolsDir = Join-Path -Path $ENV:chocolateyPackageFolder -ChildPath 'tools'

$repoInfo.assets | % {
    $fileNameFull = Join-Path -Path $toolsDir -ChildPath $_.name
    Get-ChocolateyWebFile -PackageName $ENV:chocolateyPackageName -FileFullPath $fileNameFull -Url $_.browser_download_url
}


Install-ChocolateyEnvironmentVariable -VariableName "PaketExePath" -VariableValue "paket.exe" -VariableType Machine
