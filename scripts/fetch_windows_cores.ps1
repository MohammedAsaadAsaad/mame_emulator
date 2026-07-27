# Download Windows x86_64 libretro cores + build host_helpers.dll
# Usage (from repo root, Developer PowerShell or GitHub Actions):
#   powershell -ExecutionPolicy Bypass -File .\scripts\fetch_windows_cores.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Out = Join-Path $Root "native\cores"
$Tmp = Join-Path $env:TEMP "mame_cabinet_win_cores"
New-Item -ItemType Directory -Force -Path $Out, $Tmp | Out-Null

$Base = "https://buildbot.libretro.com/nightly/windows/x86_64/latest"
$Cores = @(
  "mame2003_plus_libretro.dll",
  "fbneo_libretro.dll"
)

foreach ($core in $Cores) {
  $zip = Join-Path $Tmp "$core.zip"
  $url = "$Base/$core.zip"
  Write-Host "→ $url"
  Invoke-WebRequest -Uri $url -OutFile $zip
  Expand-Archive -Path $zip -DestinationPath $Out -Force
}

function Find-VcVars {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (-not (Test-Path $vswhere)) { return $null }
  $install = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if (-not $install) { return $null }
  $vcvars = Join-Path $install "VC\Auxiliary\Build\vcvars64.bat"
  if (Test-Path $vcvars) { return $vcvars }
  return $null
}

$HelperSrc = Join-Path $Root "native\shim\retro_shim.c"
$HelperDll = Join-Path $Root "native\host_helpers.dll"
$vcvars = Find-VcVars
if ($vcvars) {
  Write-Host "→ Building host_helpers.dll with MSVC"
  Push-Location $Root
  try {
    $cmd = "`"$vcvars`" && cl /nologo /LD /O2 /Fe:`"$HelperDll`" `"$HelperSrc`""
    cmd /c $cmd
    if ($LASTEXITCODE -ne 0) { throw "MSVC build of host_helpers.dll failed" }
  } finally {
    Remove-Item -ErrorAction SilentlyContinue `
      (Join-Path $Root "retro_shim.obj"),
      (Join-Path $Root "host_helpers.exp"),
      (Join-Path $Root "host_helpers.lib"),
      (Join-Path $Root "native\retro_shim.obj"),
      (Join-Path $Root "native\host_helpers.exp"),
      (Join-Path $Root "native\host_helpers.lib")
    Pop-Location
  }
} elseif (Get-Command gcc -ErrorAction SilentlyContinue) {
  Write-Host "→ Building host_helpers.dll with gcc"
  & gcc -shared -O2 -o $HelperDll $HelperSrc
} else {
  throw "Neither MSVC (vcvars64) nor gcc found — cannot build host_helpers.dll"
}

Write-Host "Windows natives ready:"
Get-ChildItem $Out -Filter *.dll | ForEach-Object { Write-Host "  $($_.FullName) ($([math]::Round($_.Length/1MB, 1)) MB)" }
Write-Host "  $HelperDll"
