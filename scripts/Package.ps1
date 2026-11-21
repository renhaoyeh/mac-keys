$ErrorActionPreference = 'Stop'
$repoDir = Split-Path $PSScriptRoot -Parent
$sourceDir = Join-Path $repoDir 'ahk'
$tools = & "$PSScriptRoot/Download-Tools.ps1"
$compiler = $tools.Compiler
$baseExe = $tools.AutoHotkey
$distDir = Join-Path $repoDir 'dist'
$packageDir = Join-Path $distDir 'MacKeys'
New-Item -ItemType Directory -Force "$sourceDir/build", $distDir | Out-Null
$id = [guid]::NewGuid().ToString('N')
$stage = Join-Path $distDir ".MacKeys-stage-$id"
$zipStage = Join-Path $distDir ".MacKeys-$id.zip"
$backup = Join-Path $distDir ".MacKeys-old-$id"
function Assert-UnderDist([string]$path) {
    $root = [IO.Path]::GetFullPath($distDir).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath($path)
    if (!$full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing filesystem operation outside dist: $full"
    }
}
foreach ($path in @($stage, $zipStage, $backup, $packageDir, (Join-Path $distDir 'MacKeys.zip'))) { Assert-UnderDist $path }
New-Item -ItemType Directory -Force "$stage/licenses", "$stage/source/lib" | Out-Null
function Compile-Ahk($source, $target) {
    $compileArgs = '/in "{0}" /out "{1}" /base "{2}" /compress 0 /silent verbose' -f $source, $target, $baseExe
    $process = Start-Process -FilePath $compiler -ArgumentList $compileArgs -PassThru -Wait -WindowStyle Hidden
    if ($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $target)) {
        throw "Failed to compile $source (exit $($process.ExitCode))"
    }
}
try {
    Compile-Ahk "$sourceDir/Worker.ahk" "$sourceDir/build/Worker.exe"
    Compile-Ahk "$sourceDir/MacKeymap.ahk" "$stage/MacKeysSetup.exe"
    Copy-Item -LiteralPath "$repoDir/RELEASE.txt" -Destination "$stage/README.txt"
    Copy-Item -LiteralPath $tools.License, "$repoDir/THIRD-PARTY.txt", "$sourceDir/lib/JSON-LICENSE" -Destination "$stage/licenses"
    foreach ($name in @('MacKeymap.ahk', 'Settings.ahk', 'Engine.ahk', 'Worker.ahk')) {
        Copy-Item -LiteralPath "$sourceDir/$name" -Destination "$stage/source"
    }
    Copy-Item -LiteralPath "$sourceDir/lib/JSON.ahk", "$sourceDir/lib/JSON-LICENSE" -Destination "$stage/source/lib"
    if (Get-ChildItem -LiteralPath $stage -Recurse -Filter '*.ps1') {
        throw 'Build scripts must not be included in the application package.'
    }

    Compress-Archive -Path "$stage/*" -DestinationPath $zipStage
    Move-Item -LiteralPath $zipStage -Destination (Join-Path $distDir 'MacKeys.zip') -Force

    # Swap the exploded folder only after the fresh ZIP is published. A running
    # EXE can prevent the directory rename; preserve that complete old folder.
    $explodedUpdated = $false
    try {
        $locked = $false
        foreach ($oldExe in @((Join-Path $packageDir 'MacKeys.exe'), (Join-Path $packageDir 'MacKeysSetup.exe'), (Join-Path $packageDir 'MacKeysRun.exe'))) {
            if (Test-Path -LiteralPath $oldExe) {
                try {
                    $probe = [IO.File]::Open($oldExe, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
                    $probe.Dispose()
                } catch [IO.IOException] {
                    if (($_.Exception.HResult -band 0xffff) -in 32, 33) { $locked = $true }
                    else { throw }
                }
            }
        }
        if ($locked) { throw 'An existing application executable is in use; the exploded package was left intact.' }
        if (Test-Path -LiteralPath $packageDir) {
            Move-Item -LiteralPath $packageDir -Destination $backup
        }
        try {
            Move-Item -LiteralPath $stage -Destination $packageDir
            $explodedUpdated = $true
        } catch {
            if (Test-Path -LiteralPath $backup) {
                Move-Item -LiteralPath $backup -Destination $packageDir
            }
            throw
        }
    } catch {
        Write-Warning "The ZIP is fresh, but dist/MacKeys could not be refreshed (the existing EXE may be running). Its previous contents were preserved. $($_.Exception.Message)"
    }
    if ($explodedUpdated -and (Test-Path -LiteralPath $backup)) {
        try {
            Assert-UnderDist $backup
            Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Warning "The exploded package was refreshed and the ZIP is fresh, but the obsolete backup could not be removed: $backup. $($_.Exception.Message)"
        }
    }
    Get-Item (Join-Path $distDir 'MacKeys.zip') | Select-Object FullName, Length
    if (Test-Path -LiteralPath $packageDir) {
        Get-Item (Join-Path $packageDir 'MacKeysSetup.exe') -ErrorAction SilentlyContinue | Select-Object FullName, Length
    }
} finally {
    foreach ($path in @($stage, $zipStage)) {
        if (Test-Path -LiteralPath $path) {
            Assert-UnderDist $path
            try { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop }
            catch { Write-Warning "Could not remove packaging temporary path '$path': $($_.Exception.Message)" }
        }
    }
    if (Test-Path -LiteralPath $backup) { Write-Warning "Preserving package backup '$backup'." }
}
