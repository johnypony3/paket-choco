$paketRepo = 'https://api.github.com/repos/johnypony3/Paket'
$paketInfos = Invoke-RestMethod -Uri 'https://api.github.com/repos/fsprojects/Paket/releases'
$paketRepoInfo = Invoke-RestMethod -Uri $paketRepo

$packageOutputPath = Join-Path -Path $PSScriptRoot -ChildPath 'packages'
mkdir $packageOutputPath

$packagePayloadPath = Join-Path -Path $PSScriptRoot -ChildPath '..\payload'
mkdir $packagePayloadPath

$nuspecTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath paket.template.nuspec
$nuspecPath = Join-Path -Path $PSScriptRoot -ChildPath paket.nuspec
$versionPath = Join-Path -Path $PSScriptRoot -ChildPath .version
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
    $skip = !$ogversion

    #$skip = $ogversion -notlike '*beta*'
    #$skip = $skip -or $ogversion -notlike '*3.36.0*'

    if ($skip) {
      Write-Host "skipping version:"$ogversion
      return
    }

    $version = $ogversion# -replace '-', '.03032017-'
    Write-Host "working on version:"$version

    $packageName = "Paket.$version.nupkg"
    Write-Host $packageName

    $chocoUrl = "https://packages.chocolatey.org/$packageName"
    Write-Host $chocoUrl

    if (CheckIfUploadedToChoco -chocoUrl $chocoUrl) {
      Write-Host "package exists, skipping:"$packageName
      #return;
    } else {
      Write-Host "package does not exist:"$packageName
    }

    Remove-Item "$packagePayloadPath/*" -recurse
    $repoInfo = $paketInfos | where { $_.tag_name -eq $ogversion }

    $repoInfo.assets | % {
        $fileNameFull = Join-Path -Path $packagePayloadPath -ChildPath $_.name
        Invoke-WebRequest -OutFile $fileNameFull -Uri $_.browser_download_url
        Write-Host "  -> downloaded $_.name"
    }

    [xml]$nuspec = Get-Content $nuspecTemplatePath
    $nuspec.package.metadata.id = 'paket'
    $nuspec.package.metadata.title = 'Paket'
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
    $nuspec.Save($nuspecPath)

    $ogversion | Out-File $versionPath

    choco pack $nuspecPath --outputdirectory $packageOutputPath
}

Get-ChildItem $packageOutputPath -Filter *.nupkg | % {
  choco push $_.FullName
}
