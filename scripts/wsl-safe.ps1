param(
    [string]$Distro = "Ubuntu",
    [string]$StartDir = "/home/mgta29",
    [string]$Command = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Command)) {
    & wsl.exe -d $Distro --cd $StartDir
    exit $LASTEXITCODE
}

& wsl.exe -d $Distro --cd $StartDir -e bash -lc $Command
exit $LASTEXITCODE
