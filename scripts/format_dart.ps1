param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$dartFiles = @(git ls-files -- '*.dart') | Where-Object { $_ }

if ($dartFiles.Count -eq 0) {
    Write-Host 'No tracked Dart files found.'
    exit 0
}

$batchSize = 100
for ($start = 0; $start -lt $dartFiles.Count; $start += $batchSize) {
    $end = [Math]::Min($start + $batchSize - 1, $dartFiles.Count - 1)
    $batch = $dartFiles[$start..$end]
    $formatArguments = @()
    if ($Check) {
        $formatArguments += '--set-exit-if-changed'
    }
    $formatArguments += $batch
    & dart format @formatArguments
    if ($LASTEXITCODE -ne 0) {
        throw "dart format failed for tracked files $($start + 1)-$($end + 1)."
    }
}

if ($Check) {
    Write-Host "Verified $($dartFiles.Count) tracked Dart files."
} else {
    Write-Host "Formatted $($dartFiles.Count) tracked Dart files."
}
