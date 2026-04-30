Import-Module -Name C:\projects\paket-choco\powershell-helpers\SemverSort

$secPasswd = ConvertTo-SecureString $ENV:GITHUB_PASSWORD -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($ENV:GITHUB_USERNAME, $secpasswd)

$outputPath       = Join-Path $PSScriptRoot 'output'
$nuspecTemplate   = Join-Path $PSScriptRoot '..\packages\package.nuspec'
$packagesJsonPath = Join-Path $PSScriptRoot '..\packages.json'

mkdir $outputPath -Force | Out-Null

choco apiKey -k $ENV:CHOCO_KEY -source https://push.chocolatey.org/

$push = $ENV:APPVEYOR_REPO_BRANCH -eq 'main'

function Match {
  param($a, $b, $operation)
  $compareRes = $(compareSemVer $a $b)
  switch ($operation) {
    'lower'   { $result = $compareRes -lt 0 }
    'greater' { $result = $compareRes -gt 0 }
    default   { $result = $compareRes -eq 0 }
  }
  $opRes = If ($result) { $operation } else { "not $operation" }
  Write-Host "version: $($a.VersionString) is $opRes than/to $($b.VersionString)"
  return $result
}

function GetHash {
  param([string]$filePath, [string]$algorithm)
  return (Get-FileHash $filePath -Algorithm $algorithm).Hash
}

function CheckIfUploadedToChoco {
  param([string]$packageId, [string]$packageVersion)
  Try {
    $uri = "https://community.chocolatey.org/api/v2/Packages(Id='$packageId',Version='$packageVersion')"
    $null = Invoke-WebRequest $uri -UseBasicParsing -ErrorAction Stop
    return $true
  } Catch {
    return $false
  }
}

$testVersion = $null
If (!([string]::IsNullOrEmpty($ENV:COMPARISON_VERSION))) {
  $testVersion = toSemver $ENV:COMPARISON_VERSION
}

$packages = Get-Content $packagesJsonPath | ConvertFrom-Json

foreach ($config in $packages) {
  $packageId  = $config.packageId
  $packageDir = Join-Path $PSScriptRoot "..\packages\$packageId"

  Write-Host ""
  Write-Host "=== Processing package: $packageId ==="

  $releasesUrl = "https://api.github.com/repos/$($config.githubOrg)/$($config.githubRepo)/releases"
  $repoApiUrl  = "https://api.github.com/repos/$($config.githubOrg)/$($config.githubRepo)"

  Try {
    $releases = Invoke-RestMethod -Uri $releasesUrl -Credential $credential
    $repoInfo = Invoke-RestMethod -Uri $repoApiUrl  -Credential $credential
  }
  Catch {
    Write-Host "error calling github for $packageId"
    $formatstring = "{0} : {1}`n{2}`n" +
                    "    + CategoryInfo          : {3}`n" +
                    "    + FullyQualifiedErrorId : {4}`n"
    $fields = $_.InvocationInfo.MyCommand.Name,
              $_.ErrorDetails.Message,
              $_.InvocationInfo.PositionMessage,
              $_.CategoryInfo.ToString(),
              $_.FullyQualifiedErrorId
    Write-Host -Foreground Red -Background Black ($formatstring -f $fields)
    continue
  }

  $payloadPath      = Join-Path $packageDir 'payload'
  $verificationPath = Join-Path $packageDir 'tools\VERIFICATION.txt'
  $nuspecPath       = Join-Path $PSScriptRoot "$packageId.nuspec"

  mkdir $payloadPath -Force | Out-Null

  $projectUrl = if ($config.projectUrl) { $config.projectUrl } else { $repoInfo.homepage }

  $releases | ForEach-Object {
    $release   = $_
    $skip      = $false
    $ogversion = $release.tag_name

    if ([string]::IsNullOrEmpty($ogversion)) {
      Write-Host "skipping empty tag"
      return
    }

    $semVersion = toSemver $ogversion
    $version = switch ($config.versionFormat) {
      'tag.date' { "$($semVersion.VersionString).$( ([datetime]$release.published_at).ToString('yyyyMMdd') )" }
      default    { $semVersion.VersionString }
    }

    if (!([string]::IsNullOrEmpty($ENV:OPERATION)) -and $testVersion) {
      $skip = !(Match $semVersion $testVersion $ENV:OPERATION)
    }

    if (!([string]::IsNullOrEmpty($ENV:VERSION_LIST_TO_CREATE))) {
      $versions = $ENV:VERSION_LIST_TO_CREATE.Split(',').Trim()
      $skip = $versions -notcontains $version
    }

    if ($skip) {
      Write-Host "skipping version: $version"
      return
    }

    Write-Host "working on version: $version"

    $packageName = "$packageId.$version.nupkg"

    if (CheckIfUploadedToChoco -packageId $packageId -packageVersion $version) {
      Write-Host "package exists, skipping: $packageName"
      return
    } else {
      Write-Host "package does not exist: $packageName"
    }

    Remove-Item "$payloadPath\*" -Recurse -ErrorAction SilentlyContinue

    Set-Content $verificationPath $config.verificationHeader

    $release.assets | ForEach-Object {
      $asset = $_
      if ($asset.name -notmatch $config.assetFilter) { return }

      $destPath = Join-Path $payloadPath $asset.name
      Invoke-WebRequest -OutFile $destPath -Uri $asset.browser_download_url
      Write-Host "  -> downloaded $($asset.name)"

      $hash     = GetHash $destPath $config.checksumType
      $hashInfo = "`n`tfile: $($asset.name)`n`tchecksum type: $($config.checksumType)`n`tchecksum: $hash"
      Write-Host "  -> $hashInfo"
      Add-Content $verificationPath $hashInfo

      foreach ($prop in $config.assetRenames.PSObject.Properties) {
        if ($asset.name -match $prop.Name) {
          Rename-Item $destPath $prop.Value
          break
        }
      }
    }

    Add-Content $verificationPath "`nThe download url for this packages release is <$($release.html_url)>"

    [xml]$nuspec = Get-Content $nuspecTemplate
    $nuspec.package.metadata.id               = $config.packageId
    $nuspec.package.metadata.version          = $version
    $nuspec.package.metadata.title            = $config.title
    $nuspec.package.metadata.authors          = $config.authors
    $nuspec.package.metadata.owners           = $config.owners
    $nuspec.package.metadata.licenseUrl       = $config.licenseUrl
    $nuspec.package.metadata.projectUrl       = $projectUrl
    $nuspec.package.metadata.iconUrl          = $config.iconUrl
    $nuspec.package.metadata.description      = $repoInfo.description + $config.additionalDescription
    $nuspec.package.metadata.summary          = $repoInfo.description + $config.additionalDescription
    $nuspec.package.metadata.releaseNotes     = $release.body
    $nuspec.package.metadata.tags             = $config.tags
    $nuspec.package.metadata.packageSourceUrl = $config.packageSourceUrl
    $nuspec.package.metadata.docsUrl          = $config.docsUrl
    $nuspec.package.metadata.bugTrackerUrl    = $config.bugTrackerUrl
    $nuspec.package.files.file[0].src = "..\packages\$packageId\payload\**"
    $nuspec.package.files.file[1].src = "..\packages\$packageId\tools\**"
    $nuspec.Save($nuspecPath)

    Get-Content $nuspecPath
    choco pack $nuspecPath --outputdirectory $outputPath
  }

  Remove-Item "$payloadPath\*" -Recurse -ErrorAction SilentlyContinue
}

if (!$push) {
  Write-Host "not pushing any packages"
  return 0
}

Get-ChildItem $outputPath -Filter *.nupkg | ForEach-Object {
  choco push $_.FullName
}
