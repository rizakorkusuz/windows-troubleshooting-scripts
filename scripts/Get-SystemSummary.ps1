<#
.SYNOPSIS
    Read-only summary of a Windows computer for support tickets.
.DESCRIPTION
    Collects OS, hardware, uptime, memory, BitLocker/TPM, domain or Entra join state and pending
    reboot indicators. Makes no changes to the system.
.PARAMETER AsJson
    Emit JSON instead of a formatted object.
.EXAMPLE
    .\Get-SystemSummary.ps1
.EXAMPLE
    .\Get-SystemSummary.ps1 -AsJson | Out-File summary.json
.NOTES
    Runs as a standard user. Some fields (BitLocker, TPM) need an elevated session and are
    reported as 'Unavailable (needs admin)' otherwise.
#>
[CmdletBinding()]
param(
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

function Get-Safe {
    param([scriptblock]$Script, $Default = 'Unavailable')
    try { & $Script } catch { $Default }
}

$os   = Get-Safe { Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop } $null
$cs   = Get-Safe { Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop } $null
$bios = Get-Safe { Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop } $null
$cpu  = Get-Safe { Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1 } $null

$uptime = $null
if ($os) { $uptime = (Get-Date) - $os.LastBootUpTime }

$pendingReboot = Get-Safe {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    $found = $false
    foreach ($k in $keys) { if (Test-Path $k) { $found = $true } }
    $found
} 'Unknown'

$bitlocker = Get-Safe {
    (Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop).ProtectionStatus.ToString()
} 'Unavailable (needs admin)'

$tpm = Get-Safe {
    $t = Get-Tpm -ErrorAction Stop
    "Present=$($t.TpmPresent); Ready=$($t.TpmReady)"
} 'Unavailable (needs admin)'

$join = Get-Safe {
    $out = & dsregcmd.exe /status 2>$null
    $pick = $out | Select-String -Pattern 'AzureAdJoined|DomainJoined|EnterpriseJoined|WorkplaceJoined' |
        ForEach-Object { $_.Line.Trim() }
    $pick -join '; '
} 'Unavailable'

$summary = [ordered]@{
    CollectedAt      = (Get-Date).ToString('s')
    ComputerName     = $env:COMPUTERNAME
    CurrentUser      = "$env:USERDOMAIN\$env:USERNAME"
    Manufacturer     = if ($cs) { $cs.Manufacturer } else { 'Unavailable' }
    Model            = if ($cs) { $cs.Model } else { 'Unavailable' }
    SerialNumber     = if ($bios) { $bios.SerialNumber } else { 'Unavailable' }
    BiosVersion      = if ($bios) { $bios.SMBIOSBIOSVersion } else { 'Unavailable' }
    OperatingSystem  = if ($os) { $os.Caption } else { 'Unavailable' }
    OSVersion        = if ($os) { "$($os.Version) (build $($os.BuildNumber))" } else { 'Unavailable' }
    Processor        = if ($cpu) { $cpu.Name.Trim() } else { 'Unavailable' }
    MemoryTotalGB    = if ($cs) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { 'Unavailable' }
    MemoryFreeGB     = if ($os) { [math]::Round($os.FreePhysicalMemory / 1MB, 1) } else { 'Unavailable' }
    LastBoot         = if ($os) { $os.LastBootUpTime.ToString('s') } else { 'Unavailable' }
    UptimeDays       = if ($uptime) { [math]::Round($uptime.TotalDays, 1) } else { 'Unavailable' }
    PendingReboot    = $pendingReboot
    DomainOrWorkgroup = if ($cs) { $cs.Domain } else { 'Unavailable' }
    JoinState        = $join
    BitLockerOnOSVol = $bitlocker
    Tpm              = $tpm
}

if ($AsJson) {
    $summary | ConvertTo-Json -Depth 3
} else {
    [pscustomobject]$summary
}
