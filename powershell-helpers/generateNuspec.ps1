$paketRepo = 'https://api.github.com/repos/johnypony3/Paket'
$paketInfo = Invoke-RestMethod -Uri 'https://api.github.com/repos/fsprojects/Paket/releases/5492254'
$paketRepoInfo = Invoke-RestMethod -Uri $paketRepo

[string]$releaseNotes = $paketInfo.body

$nuspecTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath paket.nuspec.template
$nuspecPath = Join-Path -Path $PSScriptRoot -ChildPath paket.nuspec
$assetPath = Join-Path -Path $PSScriptRoot -ChildPath payload

[xml]$nuspec = Get-Content $nuspecTemplatePath
$nuspec.package.metadata.id = $paketRepoInfo.name
$nuspec.package.metadata.title = $paketRepoInfo.full_name
$nuspec.package.metadata.version = $paketInfo.tag_name
$nuspec.package.metadata.authors = $paketRepoInfo.owner.login
$nuspec.package.metadata.projectUrl = $paketRepoInfo.homepage
$nuspec.package.metadata.description = $paketRepoInfo.description
$nuspec.package.metadata.summary = $paketRepoInfo.description
$nuspec.package.metadata.releaseNotes = $releaseNotes
$nuspec.package.metadata.docsUrl = $paketRepo
$nuspec.package.metadata.mailingListUrl = $paketRepo
$nuspec.package.metadata.bugTrackerUrl = $paketRepo
$nuspec.package.metadata.packageSourceUrl = $paketRepo

Remove-Item $nuspecPath -Force
Remove-Item $assetPath\* -recurse -force

#$paketInfo.assets | % {

foreach ($asset in $paketInfo.assets) {
    $fileName = $asset.browser_download_url.Substring($asset.browser_download_url.LastIndexOf("/") + 1)

    <#
    if ($fileName -ne 'paket.exe') {
        Write-Host "skipping download of $fileName"
        continue
    }
    #>
    
    Write-Host "downloading $fileName to $fileNameFull"
    #$fileName = 'paket.exe'
    $fileNameFull = Join-Path -Path $assetPath -ChildPath $fileName
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $fileNameFull
}

<#
Get-ChildItem $assetPath -recurse | % {
  New-Item "$file.ignore" -type file -force | Out-Null
}
#>

$nuspec.Save($nuspecPath)

choco pack $nuspecPath --outputdirectory=$PSScriptRoot