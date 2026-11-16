$ErrorActionPreference = 'Stop'
$cacheDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.tools'
$tools = @(
    @{
        Name = 'AutoHotkey-2.0.31'
        Url = 'https://www.autohotkey.com/download/2.0/AutoHotkey_2.0.31.zip'
        Hash = 'ca1a595aca4528755d8d4cd7fed23d497a37bd9a0b6892072612d68dee1bd00a'
        Files = @('AutoHotkey64.exe', 'license.txt')
    },
    @{
        Name = 'Ahk2Exe-1.1.37.02a2'
        Url = 'https://github.com/AutoHotkey/Ahk2Exe/releases/download/Ahk2Exe1.1.37.02a2/Ahk2Exe1.1.37.02a2.zip'
        Hash = 'c29b8c3a5124850d79fc9e66e2ca79677c377d7f31631ad3022ba159c5d9e3be'
        Files = @('Ahk2Exe.exe')
    }
)
New-Item -ItemType Directory -Force $cacheDir | Out-Null
foreach ($tool in $tools) {
    $targetDir = Join-Path $cacheDir $tool.Name
    $missing = @($tool.Files | Where-Object { !(Test-Path -LiteralPath (Join-Path $targetDir $_) -PathType Leaf) })
    if ($missing.Count -eq 0) { continue }
    $zipPath = Join-Path $cacheDir ($tool.Name + '.zip')
    Write-Host "Downloading $($tool.Name)..."
    Invoke-WebRequest -Uri $tool.Url -OutFile $zipPath
    if ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash -ne $tool.Hash) {
        throw "SHA-256 mismatch: $($tool.Name)"
    }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $targetDir -Force
    foreach ($file in $tool.Files) {
        if (!(Test-Path -LiteralPath (Join-Path $targetDir $file) -PathType Leaf)) {
            throw "Missing downloaded tool file: $($tool.Name)/$file"
        }
    }
    Remove-Item -LiteralPath $zipPath
}
[pscustomobject]@{
    AutoHotkey = Join-Path $cacheDir 'AutoHotkey-2.0.31/AutoHotkey64.exe'
    Compiler = Join-Path $cacheDir 'Ahk2Exe-1.1.37.02a2/Ahk2Exe.exe'
    License = Join-Path $cacheDir 'AutoHotkey-2.0.31/license.txt'
}
