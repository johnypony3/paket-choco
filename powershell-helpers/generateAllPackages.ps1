$paketRepo = 'https://api.github.com/repos/johnypony3/Paket'
$paketInfos = Invoke-RestMethod -Uri 'https://api.github.com/repos/fsprojects/Paket/releases'
$paketRepoInfo = Invoke-RestMethod -Uri $paketRepo
$packageOutputPath = Join-Path -Path $PSScriptRoot -ChildPath 'packages'
$nuspecTemplatePath = Join-Path -Path $PSScriptRoot -ChildPath paket.nuspec.template
$nuspecPath = Join-Path -Path $PSScriptRoot -ChildPath paket.nuspec
$assetPath = Join-Path -Path $PSScriptRoot -ChildPath payload

$paketInfos | % {
    [xml]$nuspec = Get-Content $nuspecTemplatePath
    $nuspec.package.metadata.id = $paketRepoInfo.name
    $nuspec.package.metadata.title = $paketRepoInfo.full_name
    $nuspec.package.metadata.version = $_.tag_name
    $nuspec.package.metadata.authors = $paketRepoInfo.owner.login
    $nuspec.package.metadata.projectUrl = $paketRepoInfo.homepage
    $nuspec.package.metadata.description = $paketRepoInfo.description
    $nuspec.package.metadata.summary = $paketRepoInfo.description
    $nuspec.package.metadata.releaseNotes = $_.body
    $nuspec.package.metadata.docsUrl = $paketRepo
    $nuspec.package.metadata.mailingListUrl = $paketRepo
    $nuspec.package.metadata.bugTrackerUrl = $paketRepo
    $nuspec.package.metadata.packageSourceUrl = $paketRepo

    Write-Host "working on version:"$_.tag_name

    Remove-Item $nuspecPath -Force -ErrorAction SilentlyContinue
    Remove-Item $assetPath\* -recurse -force -ErrorAction SilentlyContinue

    #$_.assets | % {

    foreach ($asset in $_.assets) {
        if ($asset.name -eq 'paket.bootstrapper.exe') {
            Write-Host "skipping download of"$asset.name
            continue
        }

        $fileNameFull = Join-Path -Path $assetPath -ChildPath $asset.name
        Write-Host "downloading"$asset.browser_download_url"to $fileNameFull"
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $fileNameFull
    }

    $nuspec.Save($nuspecPath)

    choco pack $nuspecPath --outputdirectory $packageOutputPath
}
