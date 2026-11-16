$ErrorActionPreference = 'Stop'
$repoDir = Split-Path $PSScriptRoot -Parent
$sourceDir = Join-Path $repoDir 'ahk'
$tools = & "$PSScriptRoot/Download-Tools.ps1"
$compiler = $tools.Compiler
$baseExe = $tools.AutoHotkey
$packageDir = Join-Path $repoDir 'dist/MacKeys'
New-Item -ItemType Directory -Force "$sourceDir/build", $packageDir, "$packageDir/licenses", "$packageDir/source/lib" | Out-Null
function Compile-Ahk($source, $target) {
    $compileArgs = '/in "{0}" /out "{1}" /base "{2}" /compress 0 /silent verbose' -f $source, $target, $baseExe
    $process = Start-Process -FilePath $compiler -ArgumentList $compileArgs -PassThru -Wait -WindowStyle Hidden
    if ($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $target)) {
        throw "Failed to compile $source (exit $($process.ExitCode))"
    }
}
Compile-Ahk "$sourceDir/Worker.ahk" "$sourceDir/build/Worker.exe"
Compile-Ahk "$sourceDir/MacKeymap.ahk" "$packageDir/MacKeys.exe"
Copy-Item -LiteralPath "$repoDir/RELEASE.txt" -Destination "$packageDir/README.txt" -Force
Copy-Item -LiteralPath $tools.License, "$repoDir/THIRD-PARTY.txt", "$sourceDir/lib/JSON-LICENSE" -Destination "$packageDir/licenses" -Force
foreach ($name in @('MacKeymap.ahk', 'Settings.ahk', 'Engine.ahk', 'Worker.ahk')) {
    Copy-Item -LiteralPath "$sourceDir/$name" -Destination "$packageDir/source" -Force
}
Copy-Item -LiteralPath "$sourceDir/lib/JSON.ahk", "$sourceDir/lib/JSON-LICENSE" -Destination "$packageDir/source/lib" -Force
if (Get-ChildItem -LiteralPath $packageDir -Recurse -Filter '*.ps1') {
    throw 'Build scripts must not be included in the application package.'
}
Compress-Archive -Path "$packageDir/*" -DestinationPath "$packageDir.zip" -Force
Get-Item "$packageDir/MacKeys.exe", "$packageDir.zip" | Select-Object FullName, Length
