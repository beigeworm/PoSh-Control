<# ================ POWERSHELL CONTROL ===================

SYNOPSIS
A Powershell script to monitor all PS processes, setup transcripting, view history, change settings, and defend against badUSB devices.

REQUIREMENTS
Admin privlages are required for pausing keyboard and mouse inputs
#>

# Hide the console after monitor starts
$hidden = 'y'

$Host.UI.RawUI.BackgroundColor = "Black"
Clear-Host
[Console]::SetWindowSize(50, 20)
[Console]::Title = "PoSh Control Setup"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()

Write-Host "Checking User Permissions.." -ForegroundColor DarkGray
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "Admin privileges needed for this script..." -ForegroundColor Red
    Write-Host "This script will self elevate to run as an Administrator and continue." -ForegroundColor DarkGray
    Start-Process PowerShell.exe -ArgumentList ("-NoP -Ep Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    exit
}
else{
    sleep 1
    cls
    Write-Host "This script is running as Admin!"  -ForegroundColor Green
    $directory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell
    $USBdirectory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell\USBlogs
    if (-not (Test-Path $directory)){
        New-Item -Type Directory $directory
    }
    if (-not (Test-Path $USBdirectory)){
        New-Item -Type Directory $USBdirectory
    }
}

function EnableLogging{
    Write-Host "Ckecking log registry keys.." -ForegroundColor DarkGray
    CreateRegKeys -KeyPath "HKLM:\Software\Policies\Microsoft\Windows\PowerShell"
    Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell" -Name "EnableModuleLogging" -Value 1
    Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell" -Name "EnableScriptBlockLogging" -Value 1
    Test-Path $Profile
    $directory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell
    $transcriptDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell\Transcripts
    $ps1Files = Get-ChildItem -Path $directory -Filter *.ps1
    if (-not (Test-Path $directory))
    {
        New-Item -Type Directory $directory
    }
    if (-not (Test-Path $transcriptDir))
    {
        New-Item -Type Directory $transcriptDir
    }
    
    if ($ps1Files.Count -eq 0) {
        Write-Host "Adding Powershell logging" -ForegroundColor Green
        New-Item -Type File $Profile -Force
        Write-Host "`nLOG FILES: $directory`n" -ForegroundColor Cyan
        Write-Host "Closing Script..." -ForegroundColor Red
        sleep 1
       
    }

    $scriptblock = @"
`$transcriptDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell
`$dateStamp = Get-Date -Format ((Get-culture).DateTimeFormat.SortableDateTimePattern -replace ':','.')
try {
    Start-Transcript "`$transcriptDir\Transcripts\Transcript.`$dateStamp.txt" | Out-File -FilePath "`$transcriptDir\Transcripts_Logging.txt" -Append
}
catch [System.Management.Automation.PSNotSupportedException]{
    return
} 
"@
    $scriptblock | Out-File -FilePath $Profile -Force
}

Function DisableLogging{
$directory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell
$ps1Files = Get-ChildItem -Path $directory -Filter *.ps1
if ($ps1Files.Count -gt 0) {
    Write-Host "Removing Powershell logging" -ForegroundColor Green
    Get-ChildItem -Path $directory -Filter *.ps1 | Remove-Item -Force
    sleep 3
    If (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
        Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell" -Name "EnableModuleLogging" -Value 0
        Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell" -Name "EnableScriptBlockLogging" -Value 0
    }
}

}

function ExecUnrestricted{
    Write-Host "Checking Execution Policy.." -ForegroundColor DarkGray
    $policy = Get-ExecutionPolicy
    if (($policy -ne 'Unrestricted') -or ($policy -ne 'RemoteSigned') -or ($policy -ne 'Bypass')){
        Set-ExecutionPolicy Unrestricted
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Shield
        $balloonTipTitle = "PS Logging"
        $balloonTipText = "Execution Policy Unrestricted"
        $notify.Visible = $true
        $notify.ShowBalloonTip(3000, $balloonTipTitle, $balloonTipText, [System.Windows.Forms.ToolTipIcon]::Info)
        $notify.Visible = $false
    }
}

function ExecRestricted{
    Write-Host "Checking Execution Policy.." -ForegroundColor DarkGray
    $policy = Get-ExecutionPolicy
    if (($policy -eq 'Unrestricted') -or ($policy -eq 'RemoteSigned') -or ($policy -eq 'Bypass')){
        Set-ExecutionPolicy Default
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Shield
        $balloonTipTitle = "PS Logging"
        $balloonTipText = "Execution Policy Restricted"
        $notify.Visible = $true
        $notify.ShowBalloonTip(3000, $balloonTipTitle, $balloonTipText, [System.Windows.Forms.ToolTipIcon]::Info)
        $notify.Visible = $false
    }
}

Function HideConsole{
    If ($hidden -eq 'y'){
        Write-Host "Hiding the Window.."  -ForegroundColor Red
        sleep 1
        $Async = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
        $Type = Add-Type -MemberDefinition $Async -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
        $hwnd = (Get-Process -PID $pid).MainWindowHandle
        if($hwnd -ne [System.IntPtr]::Zero){
            $Type::ShowWindowAsync($hwnd, 0)
        }
        else{
            $Host.UI.RawUI.WindowTitle = 'hideme'
            $Proc = (Get-Process | Where-Object { $_.MainWindowTitle -eq 'hideme' })
            $hwnd = $Proc.MainWindowHandle
            $Type::ShowWindowAsync($hwnd, 0)
        }
    }
}

$DeviceMonitor = {

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    $usbDevices = Get-WmiObject -Query "SELECT * FROM Win32_PnPEntity WHERE PNPDeviceID LIKE 'USB%'"
    $currentUSBDevices = @()
    $newUSBDevices = @()
    foreach ($device in $usbDevices) {
        $deviceID = $device.DeviceID
        $newUSBDevices += $deviceID
    }
    $currentUSBDevices = $newUSBDevices
    
    $monitor = {
    
        Add-Type -AssemblyName System.Drawing
        Add-Type -AssemblyName System.Windows.Forms
    
$API = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
public static extern short GetAsyncKeyState(int virtualKeyCode); 
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int GetKeyboardState(byte[] keystate);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int MapVirtualKey(uint uCode, int uMapType);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpkeystate, System.Text.StringBuilder pwszBuff, int cchBuff, uint wFlags);
'@
        $API = Add-Type -MemberDefinition $API -Name 'Win32' -Namespace API -PassThru
    
        $balloon = {
            Add-Type -AssemblyName System.Drawing
            Add-Type -AssemblyName System.Windows.Forms
            $notify = New-Object System.Windows.Forms.NotifyIcon
            $notify.Icon = [System.Drawing.SystemIcons]::Warning
            $notify.Visible = $true
            $balloonTipTitle = "WARNING"
            $balloonTipText = "Bad USB Device Intercepted!"
            $notify.ShowBalloonTip(30000, $balloonTipTitle, $balloonTipText, [System.Windows.Forms.ToolTipIcon]::WARNING)
        }
        
        $pausejob = {
            $USBdirectory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell\USBlogs
            "BadUSB Device Detected!" | Out-File -FilePath "$USBdirectory\log.log" -Append
            $s='[DllImport("user32.dll")][return: MarshalAs(UnmanagedType.Bool)]public static extern bool BlockInput(bool fBlockIt);'
            Add-Type -MemberDefinition $s -Name U -Namespace W
            [W.U]::BlockInput($true)
            sleep 10
            [W.U]::BlockInput($false)
        }
        
        function MonitorKeys {
            $startTime = $null
            $keypressCount = 0
            $initTime = Get-Date
            $USBdirectory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell\USBlogs
            "Monitor started for 30 seconds.." | Out-File -FilePath "$USBdirectory\log.log" -Append 
            while ($MonitorTime -lt $initTime.AddSeconds(30)) {
                $stopjob = Get-Content "$env:TEMP\usblogs\monon.log"
                if ($stopjob -eq 'true'){"Reastarting Monitor" | Out-File -FilePath "$USBdirectory\log.log" -Append ;exit}
                $MonitorTime = Get-Date
                Start-Sleep -Milliseconds 10
                for ($i = 8; $i -lt 256; $i++) {
                    $keyState = $API::GetAsyncKeyState($i)
                    if ($keyState -eq -32767) {
                        if (-not $startTime) {
                            $startTime = Get-Date
                        }
                        $keypressCount++
                    }
                }   
                if ($startTime -and (New-TimeSpan -Start $startTime).TotalMilliseconds -ge 200) {
                    if ($keypressCount -gt 12) {
                        $script:newUSBDeviceIDs = Get-Content "$USBdirectory\ids.log"
                        Start-Job -ScriptBlock $pausejob -Name PauseInput
                        Start-Job -ScriptBlock $balloon -Name BallonIcon
                    }
                    $startTime = $null
                    $keypressCount = 0     
                }
            }
        "Monitor set to idle." | Out-File -FilePath "$USBdirectory\log.log" -Append    
        }
    MonitorKeys
    }
    
    function CheckNew {
        $USBdirectory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell\USBlogs
        $usbDevices = Get-WmiObject -Query "SELECT * FROM Win32_PnPEntity WHERE PNPDeviceID LIKE 'USB%'"
        $newUSBDevices = @()
        foreach ($device in $usbDevices) {
            $deviceID = $device.DeviceID
            $newUSBDevices += $deviceID
            if ($currentUSBDevices -notcontains $deviceID) {
                Write-Host "New USB device added: $($device.Name) ID: $($deviceID)"
                $script:match = $true
                $newUSBDeviceIDs += $deviceID -split "," | Out-File -FilePath "$USBdirectory\ids.log" -Append
            }
        }
        $global:currentUSBDevices = $newUSBDevices
    }
    
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Shield
    $notify.Visible = $true
    $balloonTipTitle = "USB Monitoring"
    $balloonTipText = "BadUSB Monitoring Enabled"
    $notify.ShowBalloonTip(3000, $balloonTipTitle, $balloonTipText, [System.Windows.Forms.ToolTipIcon]::Info)
    
    while ($true) {
        $notify.Visible = $false
        CheckNew
        $global:CurrentStatus = 'Waiting For Devices'
        if ($match){
            Write-Host "Monitoring Keys"
            $global:CurrentStatus = 'Monitoring Inputs..'
            $jobon = Get-Job -Name Monitor
            if ($jobon){
                "true" | Out-File -FilePath "$env:TEMP\usblogs\monon.log"
                sleep -Milliseconds 500
            }
            $script:match = $false
            "false" | Out-File -FilePath "$env:TEMP\usblogs\monon.log"
            Start-Job -ScriptBlock $monitor -Name Monitor
        } 
        sleep -Milliseconds 500 
    }

}

Function BalloonPopup {
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Shield
    $notify.Visible = $true
    $notify.ShowBalloonTip(3000, $balloonTipTitle, $balloonTipText, [System.Windows.Forms.ToolTipIcon]::Info)
    $notify.Visible = $false
    sleep -m 100
}

Write-Host "Monitor Started!" -ForegroundColor Green
sleep 1 
Write-Host "Setting Window To Background.."
Write-Host "
===================================================
**YOU CAN CLOSE THE MONITOR FROM THE SYSTEM TRAY**
===================================================" -ForegroundColor Blue 
sleep 2 
HideConsole
Start-Job -ScriptBlock $DeviceMonitor -Name DeviceMonitor

$Systray_Tool_Icon = New-Object System.Windows.Forms.NotifyIcon
$Systray_Tool_Icon.Text = "PoSh Control"
$Systray_Tool_Icon.Icon = [System.Drawing.SystemIcons]::Shield
$Systray_Tool_Icon.Visible = $true

$contextmenu = New-Object System.Windows.Forms.ContextMenuStrip
$traytitle = $contextmenu.Items.Add("PoSh Control v1.0");

$Menu_BadUSB = $contextmenu.Items.Add("BadUSB Detection");
$Menu_BadUSB_Picture =[System.Drawing.Icon]::ExtractAssociatedIcon("C:\Windows\System32\fontview.exe")
$Menu_BadUSB.Image = $Menu_BadUSB_Picture

$BadUSB_SubMenu1 = New-Object System.Windows.Forms.ToolStripMenuItem
$BadUSB_SubMenu1.Text = "Enable BadUSB Detection"
$Menu_BadUSB.DropDownItems.Add($BadUSB_SubMenu1)

$BadUSB_SubMenu2 = New-Object System.Windows.Forms.ToolStripMenuItem
$BadUSB_SubMenu2.Text = "Disable BadUSB Detection"
$Menu_BadUSB.DropDownItems.Add($BadUSB_SubMenu2)

$Menu_PSlogs = $contextmenu.Items.Add("Powershell Logging");
$Menu_PSlogs_Picture =[System.Drawing.Icon]::ExtractAssociatedIcon("C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe")
$Menu_PSlogs.Image = $Menu_PSlogs_Picture

$PSlogs_SubMenu1 = New-Object System.Windows.Forms.ToolStripMenuItem
$PSlogs_SubMenu1.Text = "Enable PS Logging"
$Menu_PSlogs.DropDownItems.Add($PSlogs_SubMenu1)

$PSlogs_SubMenu2 = New-Object System.Windows.Forms.ToolStripMenuItem
$PSlogs_SubMenu2.Text = "Disable PS Logging"
$Menu_PSlogs.DropDownItems.Add($PSlogs_SubMenu2)

$Menu_ExecPol = $contextmenu.Items.Add("Execution Policy");
$Menu_ExecPol_Picture =[System.Drawing.Icon]::ExtractAssociatedIcon("C:\Windows\System32\UserAccountControlSettings.exe")
$Menu_ExecPol.Image = $Menu_ExecPol_Picture

$ExecPol_SubMenu1 = New-Object System.Windows.Forms.ToolStripMenuItem
$ExecPol_SubMenu1.Text = "Set EP Unrestricted"
$Menu_ExecPol.DropDownItems.Add($ExecPol_SubMenu1)

$ExecPol_SubMenu2 = New-Object System.Windows.Forms.ToolStripMenuItem
$ExecPol_SubMenu2.Text = "Set EP Restricted"
$Menu_ExecPol.DropDownItems.Add($ExecPol_SubMenu2)

$Menu_viewlogs = $contextmenu.Items.Add("Open Logs");
$Menu_viewlogs_Picture =[System.Drawing.Icon]::ExtractAssociatedIcon("C:\Windows\System32\magnify.exe")
$Menu_viewlogs.Image = $Menu_viewlogs_Picture

$viewlogs_SubMenu1 = New-Object System.Windows.Forms.ToolStripMenuItem
$viewlogs_SubMenu1.Text = "Open PS History"
$Menu_viewlogs.DropDownItems.Add($viewlogs_SubMenu1)

$viewlogs_SubMenu2 = New-Object System.Windows.Forms.ToolStripMenuItem
$viewlogs_SubMenu2.Text = "Open PS Transcripts"
$Menu_viewlogs.DropDownItems.Add($viewlogs_SubMenu2)

$viewlogs_SubMenu3 = New-Object System.Windows.Forms.ToolStripMenuItem
$viewlogs_SubMenu3.Text = "Open BadUSB Logs"
$Menu_viewlogs.DropDownItems.Add($viewlogs_SubMenu3)

$Menu_Exit = $contextmenu.Items.Add("Close");
$Menu_Exit_Picture =[System.Drawing.Icon]::ExtractAssociatedIcon("C:\Windows\System32\DFDWiz.exe")
$Menu_Exit.Image = $Menu_Exit_Picture

$Systray_Tool_Icon.ContextMenuStrip = $contextmenu
$appContext = New-Object System.Windows.Forms.ApplicationContext

$traytitle.add_Click({
    Start-Process msedge.exe 'https://github.com/beigeworm'
})

$BadUSB_SubMenu1.add_Click({
    $usbprocess = Get-Job -Name DeviceMonitor
    if($usbprocess.State -ne 'Running'){
        Start-Job -ScriptBlock $DeviceMonitor -Name DeviceMonitor
    }
})

$BadUSB_SubMenu2.add_Click({
    $usbprocess = Get-Job -Name DeviceMonitor
    if($usbprocess){
        Stop-Job -Name DeviceMonitor
        Remove-Job -Name DeviceMonitor
        $script:balloonTipTitle = "USB Monitoring"
        $script:balloonTipText = "BadUSB Monitoring Disabled"
        BalloonPopup
    }
})

$PSlogs_SubMenu1.add_Click({
    $directory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell
    $ps1Files = Get-ChildItem -Path $directory -Filter *.ps1
    if ($ps1Files.Count -eq 0) {
        EnableLogging
        $script:balloonTipTitle = "PS Logging"
        $script:balloonTipText = "PS Transcripts Enabled"
        BalloonPopup
    }
})

$PSlogs_SubMenu2.add_Click({
    $directory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell
    $ps1Files = Get-ChildItem -Path $directory -Filter *.ps1
    if ($ps1Files.Count -gt 0) {
        DisableLogging
        $script:balloonTipTitle = "PS Logging"
        $script:balloonTipText = "PS Transcripts Disabled"
        BalloonPopup
    }
})

$ExecPol_SubMenu1.add_Click({
    $policy = Get-ExecutionPolicy
    if (($policy -ne 'Unrestricted') -or ($policy -ne 'RemoteSigned') -or ($policy -ne 'Bypass')){
        ExecUnrestricted
    }
})

$ExecPol_SubMenu2.add_Click({
    $policy = Get-ExecutionPolicy
    if (($policy -eq 'Unrestricted') -or ($policy -eq 'RemoteSigned') -or ($policy -eq 'Bypass')){
        ExecRestricted
    }
})

$viewlogs_SubMenu1.add_Click({
    & "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
})

$viewlogs_SubMenu2.add_Click({
    $Transcriptdirectory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell\Transcripts
    explorer.exe $Transcriptdirectory
})

$viewlogs_SubMenu3.add_Click({
    $USBlogs = Join-Path ([Environment]::GetFolderPath("MyDocuments")) WindowsPowerShell\USBlogs\log.log
    & $USBlogs
})

$Menu_Exit.add_Click({
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Shield
    $balloonTipTitle = "PS Logging And Protection"
    $notify.Visible = $true
    $balloonTipText = "Closing"
    $notify.ShowBalloonTip(3000, $balloonTipTitle, $balloonTipText, [System.Windows.Forms.ToolTipIcon]::Error)
    Stop-Job -Name DeviceMonitor
    $Systray_Tool_Icon.Visible = $false
    $appContext.ExitThread()
    sleep 2
    exit    
})

[void][System.Windows.Forms.Application]::Run($appContext)
