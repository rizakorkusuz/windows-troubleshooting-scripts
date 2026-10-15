<#
.SYNOPSIS
    Read-only disk space and drive health report.
.DESCRIPTION
    Lists volumes with free space percentage and flags low space, plus physical disk health
    and operational status where available. Does not repair, clean up or delete anything.
.PARAMETER LowSpacePercent
    Free-space percentage below which a volume is flagged. Default 10.
.EXAMPLE
    .\Get-DiskHealth.ps1
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 90)]
    [int]$LowSpacePercent = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Output '== Volumes =='
try {
    Get-Volume -ErrorAction Stop |
        Where-Object { $_.DriveLetter -and $_.Size -gt 0 } |
        ForEach-Object {
            $freePct = [math]::Round(($_.SizeRemaining / $_.Size) * 100, 1)
            [pscustomobject]@{
                Drive      = "$($_.DriveLetter):"
                Label      = $_.FileSystemLabel
                FileSystem = $_.FileSystem
                SizeGB     = [math]::Round($_.Size / 1GB, 1)
                FreeGB     = [math]::Round($_.SizeRemaining / 1GB, 1)
                FreePct    = $freePct
                Flag       = if ($freePct -lt $LowSpacePercent) { 'LOW SPACE' } else { 'OK' }
                Health     = $_.HealthStatus
            }
        } | Format-Table -AutoSize
} catch {
    Write-Warning "Could not read volumes: $($_.Exception.Message)"
}

Write-Output '== Physical disks =='
try {
    Get-PhysicalDisk -ErrorAction Stop |
        Select-Object FriendlyName, MediaType, BusType,
            @{ n = 'SizeGB'; e = { [math]::Round($_.Size / 1GB, 0) } },
            HealthStatus, OperationalStatus |
        Format-Table -AutoSize
} catch {
    Write-Warning "Could not read physical disks (may need an elevated session): $($_.Exception.Message)"
}

Write-Output '== Dirty bit check (read-only) =='
try {
    Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter } | ForEach-Object {
        $line = (& fsutil.exe dirty query "$($_.DriveLetter):" 2>&1) -join ' '
        [pscustomobject]@{ Drive = "$($_.DriveLetter):"; Dirty = $line }
    } | Format-Table -AutoSize -Wrap
} catch {
    Write-Warning "Dirty bit query unavailable: $($_.Exception.Message)"
}

Write-Output 'Reminder: if a disk reports Warning or Unhealthy, back up data first, then open a hardware repair ticket.'
