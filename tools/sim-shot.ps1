param($out)
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public class WS { [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
public struct RECT { public int L,T,R,B; } }
'@
$p = Get-Process simulator | Select-Object -First 1
[WS]::ShowWindow($p.MainWindowHandle, 9) | Out-Null; [WS]::SetForegroundWindow($p.MainWindowHandle) | Out-Null; Start-Sleep -Milliseconds 600
$r = New-Object WS+RECT; [WS]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
$bmp = New-Object System.Drawing.Bitmap ($r.R-$r.L),($r.B-$r.T)
[System.Drawing.Graphics]::FromImage($bmp).CopyFromScreen($r.L,$r.T,0,0,$bmp.Size)
$bmp.Save($out); [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
