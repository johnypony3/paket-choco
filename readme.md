[![Build Status](https://travis-ci.org/johnypony3/paket-choco.svg?branch=master)](https://travis-ci.org/johnypony3/paket-choco)

# purpose:

## create chocolatey packages of the paket nuget manager

# execution steps

1. this looks at the releases of the paket repo
2. pulls all of the nuget packages based on release tags
3. pull all of the artifacts from the release page, minus the bootstrapper
4. extracts the nuget packages
5. updates the nuspec metadata file
6. puts the release artifacts into the packages
7. compresses into a chocolatey packages
8. pushes all packages missing from the chocolatey repo to chocolatey
