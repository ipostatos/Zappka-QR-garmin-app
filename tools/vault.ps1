# Windows DPAPI vault for the Zappka account data (audit ZG-01). Bound to the current Windows user.
#   pwsh tools/vault.ps1 put <secrets.json>   encrypt into the vault, then delete the plaintext yourself
#   pwsh tools/vault.ps1 get                  print the JSON to stdout (pipe it, never redirect to a file)
param([Parameter(Mandatory)][ValidateSet('put','get')]$cmd, $src)
Add-Type -AssemblyName System.Security
$vault = Join-Path $env:USERPROFILE '.zappka-vault\secrets.json.dpapi'
if ($cmd -eq 'put') {
    New-Item -ItemType Directory -Force (Split-Path $vault) | Out-Null
    $plain = [IO.File]::ReadAllBytes((Resolve-Path $src))
    [IO.File]::WriteAllBytes($vault, [Security.Cryptography.ProtectedData]::Protect($plain, $null, 'CurrentUser'))
    "stored in $vault"
} else {
    $b = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($vault), $null, 'CurrentUser')
    [Console]::Out.Write([Text.Encoding]::UTF8.GetString($b))
}
