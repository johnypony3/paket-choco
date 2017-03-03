$paketRepo = 'https://api.github.com/repos/johnypony3/Paket'
$paketInfos = Invoke-RestMethod -Uri 'https://api.github.com/repos/fsprojects/Paket/releases'
$paketRepoInfo = Invoke-RestMethod -Uri $paketRepo
$packageOutputPath = Join-Path -Path $PSScriptRoot -ChildPath 'packages'
mkdir $packageOutputPath

$nuspecTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath paket.template.nuspec
$nuspecPath = Join-Path -Path $PSScriptRoot -ChildPath paket.nuspec
$assetPath = Join-Path -Path $PSScriptRoot -ChildPath payload

choco apiKey -k $ENV:CHOCO_KEY -source https://chocolatey.org/

function CheckIfUploadedToChoco {
  param([string]$chocoUrl)

  Try {
    $statusCode = wget $chocoUrl | % {$_.StatusCode}
    Write-Host "$statusCode for $chocoUrl"
    if ($statusCode -eq '200') {
      return $true
    }
  } Catch {
    Write-Host "$statusCode for $chocoUrl"
    return $false
  }
}

$paketInfos | % {
    $ogversion = $_.tag_name

    $skip = $false
    #$skip = $ogversion -notlike '*beta*'
    $skip = $skip -or $ogversion -like '*3.36.0*'

    if ($skip) {
      Write-Host "skipping version:"$ogversion
      return
    }

    $version = $ogversion -replace '-', '.03022017-'
    Write-Host "working on version:"$version

    $packageName = "Paket.$version.nupkg"
    Write-Host $packageName

    $chocoUrl = "https://packages.chocolatey.org/$packageName"
    Write-Host $chocoUrl

    if (CheckIfUploadedToChoco -chocoUrl $chocoUrl) {
      Write-Host "package exists, skipping:"$packageName
      //return;
    } else {
      Write-Host "package does not exist:"$packageName
    }

    [xml]$nuspec = Get-Content $nuspecTemplatePath
    $nuspec.package.metadata.id = 'paket'
    $nuspec.package.metadata.title = 'paket'
    $nuspec.package.metadata.version = $version
    $nuspec.package.metadata.authors = $paketRepoInfo.owner.login
    $nuspec.package.metadata.projectUrl = $paketRepoInfo.homepage
    $nuspec.package.metadata.description = $paketRepoInfo.description
    $nuspec.package.metadata.summary = $paketRepoInfo.description
    $nuspec.package.metadata.releaseNotes = $_.body
    $nuspec.package.metadata.docsUrl = $paketRepo
    $nuspec.package.metadata.mailingListUrl = $paketRepo
    $nuspec.package.metadata.bugTrackerUrl = $paketRepo
    $nuspec.package.metadata.packageSourceUrl = $paketRepo

    $nuspec.package.metadata.tags = $ogversion

    $nuspec.Save($nuspecPath)

    $ogversion | Out-File .\tools\.version

    choco pack $nuspecPath --outputdirectory $packageOutputPath
}

Get-ChildItem $packageOutputPath -Filter *.nupkg | % {
  choco push $_.FullName
}
