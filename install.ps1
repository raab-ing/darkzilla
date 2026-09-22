# darkzilla installer / updater
#
# Easiest: double-click install.cmd (or update.cmd) - .cmd files are not
# subject to the PowerShell execution policy, so they always run.
#
# You can also install without downloading the zip first:
#
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm 'https://raw.githubusercontent.com/raab-ing/darkzilla/main/install.ps1')"
#
# Parameters:
#   -InstallDir <path>   Install location (default: %LOCALAPPDATA%\darkzilla)
#   -Repo <owner/name>   GitHub repo to fetch releases from
#   -Update              Force download of the latest release (install.cmd
#                        without -Update installs from the zip it sits in)
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\darkzilla",
    [string]$Repo = "raab-ing/darkzilla",
    [switch]$Update
)

$ErrorActionPreference = 'Stop'

function New-DarkzillaShortcut {
    param([string]$ExePath)
    $lnkDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    $shell = New-Object -ComObject WScript.Shell
    foreach ($target in @("$lnkDir\darkzilla.lnk",
                         "$env:USERPROFILE\Desktop\darkzilla.lnk")) {
        try {
            $sc = $shell.CreateShortcut($target)
            $sc.TargetPath = $ExePath
            $sc.WorkingDirectory = Split-Path $ExePath
            $sc.Description = "darkzilla - FileZilla with Windows dark mode"
            $sc.Save()
            Write-Host "Created shortcut: $target"
        } catch {
            Write-Warning "Could not create shortcut $target`: $_"
        }
    }
}

# Does this script sit next to a filezilla.exe payload (extracted zip or an
# existing install)? When run remotely via iex there is no script dir at all.
$payloadDir = $PSScriptRoot
$hasPayload = $payloadDir -and (Test-Path (Join-Path $payloadDir 'filezilla.exe'))

if ($Update -or -not $hasPayload) {
    # Download-and-install path: used by -Update, update.cmd, and remote iex.
    Write-Host "Fetching latest darkzilla release from github.com/$Repo ..."
    $rel = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $asset = $rel.assets | Where-Object { $_.name -like '*win64*.zip' } | Select-Object -First 1
    if (-not $asset) { throw "No win64 zip found in latest release ($($rel.tag_name))." }

    $tmp = Join-Path $env:TEMP ("darkzilla-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $zipPath = Join-Path $tmp $asset.name
    Write-Host "Downloading $($asset.name) ($([math]::Round($asset.size/1MB,1)) MB)..."
    Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath

    Write-Host "Extracting..."
    $extract = Join-Path $tmp "x"
    Expand-Archive $zipPath -DestinationPath $extract
    $payload = Get-ChildItem $extract -Directory | Select-Object -First 1
    if (-not $payload) { $payload = $extract }

    New-Item -ItemType Directory -Force $InstallDir | Out-Null
    Write-Host "Installing to $InstallDir ..."
    Copy-Item "$($payload.FullName)\*" $InstallDir -Recurse -Force

    Remove-Item -Recurse -Force $tmp
    New-DarkzillaShortcut (Join-Path $InstallDir 'filezilla.exe')
    Write-Host "Done. darkzilla $($rel.tag_name) installed to $InstallDir"
    exit 0
}

# Local install: copy this extracted payload to the install dir.
New-Item -ItemType Directory -Force $InstallDir | Out-Null
Write-Host "Installing darkzilla to $InstallDir ..."
Copy-Item "$payloadDir\*" $InstallDir -Recurse -Force
New-DarkzillaShortcut (Join-Path $InstallDir 'filezilla.exe')
Write-Host "Done. Launch via the 'darkzilla' shortcut or $InstallDir\filezilla.exe"
Write-Host "To update later: run $InstallDir\update.cmd"
