# Windows MSIX code signing for Termex.
#
# Required env:
#   CERT_THUMBPRINT   SHA1 thumbprint of the code-signing certificate
#                     (installed in the CurrentUser\My store)
#   MSIX_PATH         Path to the MSIX package to sign
#
# Uses RFC 3161 timestamp server so signatures remain valid after the
# certificate expires.
param(
    [string]$CertThumbprint = $env:CERT_THUMBPRINT,
    [string]$MsixPath = $env:MSIX_PATH
)

$ErrorActionPreference = "Stop"

if (-not $CertThumbprint) { throw "CERT_THUMBPRINT not set" }
if (-not $MsixPath) { throw "MSIX_PATH not set" }
if (-not (Test-Path $MsixPath)) { throw "MSIX not found: $MsixPath" }

$signToolCandidates = @(
    "C:\Program Files (x86)\Windows Kits\10\bin\x64\signtool.exe",
    "C:\Program Files\Windows Kits\10\bin\x64\signtool.exe"
)
$SignTool = $signToolCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $SignTool) { throw "signtool.exe not found in Windows SDK paths" }

Write-Host "→ signing $MsixPath with thumbprint $CertThumbprint"
& $SignTool sign `
    /sha1 $CertThumbprint `
    /fd SHA256 `
    /tr http://timestamp.digicert.com `
    /td SHA256 `
    $MsixPath

if ($LASTEXITCODE -ne 0) { throw "signtool failed with exit $LASTEXITCODE" }

Write-Host "✓ Windows signing complete: $MsixPath"
