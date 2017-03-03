[![Build status](https://ci.appveyor.com/api/projects/status/2xgqtr4xtio1x1ft/branch/master?svg=true)](https://ci.appveyor.com/project/johnypony3/paket-choco/branch/master)

# purpose:

## create chocolatey packages of the paket nuget manager

# execution steps

1. make get call to github api for the repo
2. uses template for metadata and pulls data from github call above
3. package looks at the version of itself and pulls matching artifacts, as versions match 1:1
4. pack / push
