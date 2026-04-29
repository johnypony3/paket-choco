[![Build status](https://ci.appveyor.com/api/projects/status/2xgqtr4xtio1x1ft/branch/master?svg=true)](https://ci.appveyor.com/project/johnypony3/paket-choco/branch/master)

# purpose:

Builds and publishes Chocolatey packages for:
- **Paket** — https://push.chocolatey.org/packages/Paket
- **Cloudbase-Init** — https://push.chocolatey.org/packages/cloudbaseinit

# execution steps

1. make get call to github api for the repo
2. uses template for metadata and pulls data from github call above
3. downloads release artifacts into payload and embeds them in the package
4. pack / push
