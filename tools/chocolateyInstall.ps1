$ErrorActionPreference = 'Stop';

Install-ChocolateyEnvironmentVariable -VariableName "PaketExePath" -VariableValue "paket.exe" -VariableType Machine
