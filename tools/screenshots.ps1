# Simulator screenshots with the PUBLIC EXAMPLE account (not a real account).
# usage: pwsh tools/screenshots.ps1 <device> <developer_key.der> <out.png> [-NoAccount] [-Wait 12]
# Clear the simulator app data first (GARMIN/APPS/DATA and SETTINGS in %TEMP%/com.garmin.connectiq),
# otherwise the simulator reuses the blanked settings of an earlier run.
# Builds screenshot.jungle (no glance, so the QR view opens directly), restores properties.xml
# afterwards, launches the app in a running simulator and saves the device display area.
param([Parameter(Mandatory)]$Device, [Parameter(Mandatory)]$Key, [Parameter(Mandatory)]$Out, $Keys = "", [int]$Wait = 12, [switch]$NoAccount)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sdk = Get-ChildItem "$env:APPDATA\Garmin\ConnectIQ\Sdks" -Directory | Sort-Object Name | Select-Object -Last 1
$props = Join-Path $root 'resources\settings\properties.xml'; $bak = Get-Content $props -Raw
$prg = Join-Path $root "bin\shot-$Device.prg"
try {
    if (-not $NoAccount) { Set-Content $props -NoNewline -Value "<properties>`n    <property id=`"userId`" type=`"string`">123456789012</property>`n    <property id=`"secret`" type=`"string`">2db76449a55d59f1f9420b809edb1beb19dfa434ddb5dbf331f01aec35956e35</property>`n</properties>`n" }
    & "$($sdk.FullName)\bin\monkeyc.bat" -f (Join-Path $root 'screenshot.jungle') -d $Device -o $prg -y $Key | Out-Null
} finally { Set-Content $props -NoNewline -Value $bak }
Start-Job -ScriptBlock { param($s,$p,$d) & "$s\bin\monkeydo.bat" $p $d } -ArgumentList $sdk.FullName,$prg,$Device | Out-Null
Start-Sleep $Wait
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
Add-Type @'
using System; using System.Runtime.InteropServices;
public class SimWin { [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h,int x,int y,int w,int hh,bool r); [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); public struct R { public int L,T,Rr,B; } }
'@
$p = Get-Process simulator | Where-Object { $_.MainWindowTitle -like 'CIQ Simulator*' } | Select-Object -First 1
[SimWin]::MoveWindow($p.MainWindowHandle, 0, 0, 760, 860, $true) | Out-Null
[SimWin]::SetForegroundWindow($p.MainWindowHandle) | Out-Null; Start-Sleep -Milliseconds 600
foreach ($k in ($Keys -split ',' | Where-Object { $_ })) { [System.Windows.Forms.SendKeys]::SendWait("{$k}"); Start-Sleep -Milliseconds 900 }
$r = New-Object SimWin+R; [SimWin]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
$bmp = New-Object System.Drawing.Bitmap ($r.Rr-$r.L), ($r.B-$r.T)
[System.Drawing.Graphics]::FromImage($bmp).CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$bmp.Save($Out); "saved $Out"
