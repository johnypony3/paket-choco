[![Build status](https://ci.appveyor.com/api/projects/status/2xgqtr4xtio1x1ft/branch/master?svg=true)](https://ci.appveyor.com/project/johnypony3/paket-choco/branch/master)

# purpose:

## create chocolatey packages of the paket nuget manager
## end result: https://push.chocolatey.org/packages/Paket

# execution steps

1. make get call to github api for the repo
2. uses template for metadata and pulls data from github call above
3. package looks at the .version file and pulls matching artifacts
4. pack / push
