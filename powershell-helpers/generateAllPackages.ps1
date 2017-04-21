$paketRepo = 'https://api.github.com/repos/fsprojects/Paket'
$paketInfos = Invoke-RestMethod -Uri 'https://api.github.com/repos/fsprojects/Paket/releases'
$paketRepoInfo = Invoke-RestMethod -Uri $paketRepo

$packageOutputPath = Join-Path -Path $PSScriptRoot -ChildPath 'packages'
mkdir $packageOutputPath

$packagePayloadPath = Join-Path -Path $PSScriptRoot -ChildPath '..\payload'
mkdir $packagePayloadPath

$nuspecTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath paket.template.nuspec
$verificationTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath VERIFICATION.template.txt

$nuspecPath = Join-Path -Path $PSScriptRoot -ChildPath paket.nuspec
$verificationPath = Join-Path -Path $PSScriptRoot -ChildPath ..\tools\VERIFICATION.txt

$versionPath = Join-Path -Path $PSScriptRoot -ChildPath .version
$assetPath = Join-Path -Path $PSScriptRoot -ChildPath payload
$checksumType = "MD5"

choco apiKey -k $ENV:CHOCO_KEY -source https://chocolatey.org/

$push = false

function BuildInfoFileGenerator {
  param([string]$ogVersion)

  $hash = @{}
  $hash.Add("APPVEYOR", $ENV:APPVEYOR)
  $hash.Add("CI", $ENV:CI)
  $hash.Add("APPVEYOR_API_URL", $ENV:APPVEYOR_API_URL)
  $hash.Add("APPVEYOR_ACCOUNT_NAME", $ENV:APPVEYOR_ACCOUNT_NAME)
  $hash.Add("APPVEYOR_PROJECT_ID", $ENV:APPVEYOR_PROJECT_ID)
  $hash.Add("APPVEYOR_PROJECT_NAME", $ENV:APPVEYOR_PROJECT_NAME)
  $hash.Add("APPVEYOR_PROJECT_SLUG", $ENV:APPVEYOR_PROJECT_SLUG)
  $hash.Add("APPVEYOR_BUILD_FOLDER", $ENV:APPVEYOR_BUILD_FOLDER)
  $hash.Add("APPVEYOR_BUILD_ID", $ENV:APPVEYOR_BUILD_ID)
  $hash.Add("APPVEYOR_BUILD_NUMBER", $ENV:APPVEYOR_BUILD_NUMBER)
  $hash.Add("APPVEYOR_BUILD_VERSION", $ENV:APPVEYOR_BUILD_VERSION)
  $hash.Add("APPVEYOR_BUILD_WORKER_IMAGE", $ENV:APPVEYOR_BUILD_WORKER_IMAGE)
  $hash.Add("APPVEYOR_PULL_REQUEST_NUMBER", $ENV:APPVEYOR_PULL_REQUEST_NUMBER)
  $hash.Add("APPVEYOR_PULL_REQUEST_TITLE", $ENV:APPVEYOR_PULL_REQUEST_TITLE)
  $hash.Add("APPVEYOR_JOB_ID", $ENV:APPVEYOR_JOB_ID)
  $hash.Add("APPVEYOR_JOB_NAME", $ENV:APPVEYOR_JOB_NAME)
  $hash.Add("APPVEYOR_JOB_NUMBER", $ENV:APPVEYOR_JOB_NUMBER)
  $hash.Add("APPVEYOR_REPO_PROVIDER", $ENV:APPVEYOR_REPO_PROVIDER)
  $hash.Add("APPVEYOR_REPO_SCM", $ENV:APPVEYOR_REPO_SCM)
  $hash.Add("APPVEYOR_REPO_NAME", $ENV:APPVEYOR_REPO_NAME)
  $hash.Add("APPVEYOR_REPO_BRANCH", $ENV:APPVEYOR_REPO_BRANCH)
  $hash.Add("APPVEYOR_REPO_TAG", $ENV:APPVEYOR_REPO_TAG)
  $hash.Add("APPVEYOR_REPO_TAG_NAME", $ENV:APPVEYOR_REPO_TAG_NAME)
  $hash.Add("APPVEYOR_REPO_COMMIT", $ENV:APPVEYOR_REPO_COMMIT)
  $hash.Add("APPVEYOR_REPO_COMMIT_AUTHOR", $ENV:APPVEYOR_REPO_COMMIT_AUTHOR)
  $hash.Add("APPVEYOR_REPO_COMMIT_AUTHOR_EMAIL", $ENV:APPVEYOR_REPO_COMMIT_AUTHOR_EMAIL)
  $hash.Add("APPVEYOR_REPO_COMMIT_TIMESTAMP", $ENV:APPVEYOR_REPO_COMMIT_TIMESTAMP)
  $hash.Add("APPVEYOR_REPO_COMMIT_MESSAGE", $ENV:APPVEYOR_REPO_COMMIT_MESSAGE)
  $hash.Add("APPVEYOR_REPO_COMMIT_MESSAGE_EXTENDED", $ENV:APPVEYOR_REPO_COMMIT_MESSAGE_EXTENDED)
  $hash.Add("APPVEYOR_SCHEDULED_BUILD", $ENV:APPVEYOR_SCHEDULED_BUILD)
  $hash.Add("PLATFORM", $ENV:PLATFORM)
  $hash.Add("VERSION", $ENV:PLATFORM)
  $hash.Add("CONFIGURATION", $ogVersion)

  $hash | ConvertTo-Json | Out-File $versionPath
}

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

function GetHash{
  param([string]$filePath)

  $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
  $hash = [System.BitConverter]::ToString($md5.ComputeHash([System.IO.File]::ReadAllBytes($filePath)))
  return $hash
}

$paketInfos | % {
    $ogversion = $_.tag_name
    $downloadUrl = $_.html_url

    $skip = $false
    $skip = !$ogversion

    $overrideExistingPackageCheck = $true

    #$skip = $ogversion -notlike '*beta*'
    $skip = $skip -or $ogversion -notlike '*4.0.7*'

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
      if (!($overrideExistingPackageCheck)){
        Write-Host "package exists, skipping:"$packageName
        return;
      }

      Write-Host "package exists, continuing:"$packageName
    } else {
      Write-Host "package does not exist:"$packageName
    }

    Remove-Item "$packagePayloadPath/*" -recurse
    $repoInfo = $paketInfos | where { $_.tag_name -eq $ogversion }

    Copy-Item $verificationTemplatePath $verificationPath

    $repoInfo.assets | % {
        $fileNameFull = Join-Path -Path $packagePayloadPath -ChildPath $_.name
        Invoke-WebRequest -OutFile $fileNameFull -Uri $_.browser_download_url
        Write-Host "  -> downloaded $_.name"
        $fileHash = GetHash $fileNameFull
        $fileHashInfo = "`n`tfile: $_.name`n`tchecksum type: $checksumType`n`tchecksum: $fileHash`n"
        Write-Host "  -> $fileHashInfo"
        Add-Content $verificationPath $fileHashInfo
    }

    Add-Content $verificationPath "The download url for this packages release is <$downloadUrl>"

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

    BuildInfoFileGenerator $ogversion

    choco pack $nuspecPath --outputdirectory $packageOutputPath
}

if (!($push)){
  Write-Host "not pushing any packages"
  return 0;
}

Get-ChildItem $packageOutputPath -Filter *.nupkg | % {
  choco push $_.FullName
}
