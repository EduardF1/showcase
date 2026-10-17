#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $script:Gate = Join-Path $PSScriptRoot '..' 'Invoke-RatchetGate.ps1'
    $script:Pwsh = (Get-Process -Id $PID).Path

    # Writes an ESLint shaped report: one file, with N messages per rule. A $null rule is a parse error.
    function New-Report([hashtable] $Counts) {
        $messages = foreach ($rule in $Counts.Keys) {
            for ($i = 0; $i -lt $Counts[$rule]; $i++) { @{ ruleId = if ($rule -eq '') { $null } else { $rule } } }
        }
        $path = Join-Path $TestDrive "report-$([guid]::NewGuid()).json"
        ConvertTo-Json -InputObject @(@{ filePath = 'src/a.js'; messages = @($messages) }) -Depth 5 |
            Set-Content -LiteralPath $path
        $path
    }

    function New-Baseline([hashtable] $Counts) {
        $path = Join-Path $TestDrive "baseline-$([guid]::NewGuid()).json"
        $Counts | ConvertTo-Json | Set-Content -LiteralPath $path
        $path
    }

    function Read-Baseline([string] $Path) {
        $out = @{}
        foreach ($p in (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json).PSObject.Properties) { $out[$p.Name] = [int] $p.Value }
        $out
    }

    # The gate calls exit, so it runs in its own process and the exit code is the verdict.
    function Invoke-Gate([string] $Report, [string] $Baseline, [switch] $UpdateBaseline) {
        $arguments = @('-NoProfile', '-NonInteractive', '-File', $script:Gate, '-ReportPath', $Report, '-BaselinePath', $Baseline)
        if ($UpdateBaseline) { $arguments += '-UpdateBaseline' }
        $output = & $script:Pwsh @arguments 2>&1 | Out-String
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    }
}

Describe 'Invoke-RatchetGate' {
    It 'parses without errors' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:Gate, [ref] $null, [ref] $errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }

    It 'passes when no rule count has moved' {
        $baseline = New-Baseline @{ 'no-var' = 2; 'eqeqeq' = 1 }
        $result = Invoke-Gate (New-Report @{ 'no-var' = 2; 'eqeqeq' = 1 }) $baseline

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'No new violations\. 3 total across 2 rules\.'
    }

    It 'fails when a rule count goes up, and names the rule' {
        $result = Invoke-Gate (New-Report @{ 'no-var' = 3 }) (New-Baseline @{ 'no-var' = 2 })

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'no-var\s+2 -> 3'
    }

    It 'counts per rule, so fixing forty of one rule does not buy three of another' {
        $baseline = New-Baseline @{ 'no-var' = 50; 'security/detect-eval' = 0 }
        $result = Invoke-Gate (New-Report @{ 'no-var' = 10; 'security/detect-eval' = 3 }) $baseline

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'security/detect-eval\s+0 -> 3'
    }

    It 'counts a message with no ruleId as a parse error rather than hiding it in the total' {
        $result = Invoke-Gate (New-Report @{ 'no-var' = 1; '' = 1 }) (New-Baseline @{ 'no-var' = 2 })

        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\(parse-error\)\s+0 -> 1'
    }

    It 'does not touch the baseline on an improvement unless asked' {
        $baseline = New-Baseline @{ 'no-var' = 5 }
        $before = Get-Content -LiteralPath $baseline -Raw
        $result = Invoke-Gate (New-Report @{ 'no-var' = 3 }) $baseline

        $result.ExitCode | Should -Be 0
        Get-Content -LiteralPath $baseline -Raw | Should -Be $before
    }

    It 'lowers the baseline on an improvement with -UpdateBaseline' {
        $baseline = New-Baseline @{ 'no-var' = 5; 'eqeqeq' = 2 }
        $result = Invoke-Gate (New-Report @{ 'no-var' = 3; 'eqeqeq' = 2 }) $baseline -UpdateBaseline

        $result.ExitCode | Should -Be 0
        $written = Read-Baseline $baseline
        $written['no-var'] | Should -Be 3
        $written['eqeqeq'] | Should -Be 2
    }

    It 'never raises the baseline, even with -UpdateBaseline, when a rule regresses' {
        $baseline = New-Baseline @{ 'no-var' = 5; 'eqeqeq' = 2 }
        $before = Get-Content -LiteralPath $baseline -Raw
        $result = Invoke-Gate (New-Report @{ 'no-var' = 1; 'eqeqeq' = 4 }) $baseline -UpdateBaseline

        $result.ExitCode | Should -Be 1
        Get-Content -LiteralPath $baseline -Raw | Should -Be $before
    }

    It 'passes a clean report against an existing baseline' {
        $result = Invoke-Gate (New-Report @{}) (New-Baseline @{ 'no-var' = 5 })

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'improved\s+no-var\s+5 -> 0'
    }

    It 'fails loudly when the report is missing, rather than passing an empty one' {
        $result = Invoke-Gate (Join-Path $TestDrive 'nope.json') (New-Baseline @{ 'no-var' = 1 })

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Lint report not found'
    }
}
