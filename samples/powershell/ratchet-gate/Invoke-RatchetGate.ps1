<#
.SYNOPSIS
    Fails when a lint rule's violation count goes UP, and lowers the baseline when it goes down.

.DESCRIPTION
    Turning a rule on in a codebase that already breaks it two thousand times leaves two bad
    options: fail the build and block everyone, or warn and watch the count grow. The ratchet is the
    third: new code is held to the rule from day one, old code is cleaned when someone is in there
    anyway, and the gate makes each cleanup permanent.

    Counts are per rule, never a single total. One total lets somebody fix forty easy violations of
    one rule while adding three of a rule that matters, and the gate stays quiet.

.PARAMETER ReportPath
    ESLint JSON output, or anything with the same shape: an array of files, each with a messages
    array whose entries carry a ruleId.

.PARAMETER BaselinePath
    The committed counts. Created on first run.

.PARAMETER UpdateBaseline
    Write improvements back. Off by default so a normal CI run cannot silently change the baseline.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ReportPath,
    [Parameter(Mandatory)] [string] $BaselinePath,
    [switch] $UpdateBaseline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ReportPath)) {
    throw "Lint report not found at '$ReportPath'. A missing report must fail loudly: an empty one would pass every check."
}

$report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json

# Count per rule. A message with no ruleId is a parse error rather than a rule violation, and it is
# counted under its own name so it cannot hide inside the total.
$current = @{}
foreach ($file in $report) {
    foreach ($message in $file.messages) {
        $rule = if ([string]::IsNullOrWhiteSpace($message.ruleId)) { '(parse-error)' } else { $message.ruleId }
        $current[$rule] = ($current[$rule] ?? 0) + 1
    }
}

$baseline = @{}
if (Test-Path -LiteralPath $BaselinePath) {
    $loaded = Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json
    foreach ($property in $loaded.PSObject.Properties) { $baseline[$property.Name] = [int] $property.Value }
}
else {
    Write-Host "No baseline at '$BaselinePath'; recording today's counts as the starting point."
}

$regressions = @()
$improvements = @()
foreach ($rule in ($current.Keys + $baseline.Keys | Sort-Object -Unique)) {
    $now = [int] ($current[$rule] ?? 0)
    $was = [int] ($baseline[$rule] ?? 0)
    if ($now -gt $was) { $regressions += [pscustomobject]@{ Rule = $rule; Was = $was; Now = $now } }
    elseif ($now -lt $was) { $improvements += [pscustomobject]@{ Rule = $rule; Was = $was; Now = $now } }
}

foreach ($row in $improvements) {
    Write-Host ("  improved  {0,-44} {1} -> {2}" -f $row.Rule, $row.Was, $row.Now)
}

if ($regressions.Count -gt 0) {
    Write-Host ''
    Write-Host 'NEW violations, which is the only thing this gate blocks on:' -ForegroundColor Red
    foreach ($row in $regressions) {
        Write-Host ("  {0,-44} {1} -> {2}" -f $row.Rule, $row.Was, $row.Now) -ForegroundColor Red
    }
    # The baseline is NOT raised here, even with -UpdateBaseline. Loosening the gate has to be an
    # explicit commit a reviewer can see, not something a failing run did on its way out.
    exit 1
}

if ($UpdateBaseline -and ($improvements.Count -gt 0 -or -not (Test-Path -LiteralPath $BaselinePath))) {
    $next = [ordered]@{}
    foreach ($rule in ($current.Keys | Sort-Object)) { $next[$rule] = $current[$rule] }
    $next | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $BaselinePath -Encoding utf8
    Write-Host "Baseline lowered and written to '$BaselinePath'."
}

$total = ($current.Values | Measure-Object -Sum).Sum
Write-Host "No new violations. $total total across $($current.Count) rules."
exit 0
