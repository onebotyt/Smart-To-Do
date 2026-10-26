[CmdletBinding()]
param(
    [switch]$Watch,
    [string]$Commit,
    [string]$Run,
    [string]$Repo = "onebotyt/Smart-To-Do"
)

$dartExe = "C:\flutter\bin\cache\dart-sdk\bin\dart.exe"
if (-not (Test-Path $dartExe)) {
    $dartExe = "dart"
}

$scriptPath = Join-Path $PSScriptRoot "check_build.dart"
$argsList = @($scriptPath)

if ($Watch) { $argsList += "--watch" }
if ($Commit) { $argsList += "--commit=$Commit" }
if ($Run) { $argsList += "--run=$Run" }
if ($Repo) { $argsList += "--repo=$Repo" }

& $dartExe @argsList
