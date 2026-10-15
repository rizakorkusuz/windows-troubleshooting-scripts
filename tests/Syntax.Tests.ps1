# Pester 5 tests: every script must parse without errors and declare CmdletBinding.
BeforeDiscovery {
    $scriptFiles = Get-ChildItem -Path (Join-Path $PSScriptRoot '..' 'scripts') -Filter '*.ps1' | ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
}

Describe 'Script quality' {
    It '<Name> parses without syntax errors' -ForEach $scriptFiles {
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }
    It '<Name> has comment-based help and CmdletBinding' -ForEach $scriptFiles {
        $text = Get-Content -Raw -Path $Path
        $text | Should -Match '\.SYNOPSIS'
        $text | Should -Match '\[CmdletBinding\(\)\]'
    }
    It '<Name> contains no state-changing cmdlets' -ForEach $scriptFiles {
        $text = Get-Content -Raw -Path $Path
        $text | Should -Not -Match '\b(Remove-Item|Set-ItemProperty|Stop-Service|Restart-Service|Clear-DnsClientCache|Set-NetIPAddress|Restart-Computer|Stop-Computer)\b'
    }
}
