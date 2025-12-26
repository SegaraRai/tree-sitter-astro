$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-RepoRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $rel = (Resolve-Path -Relative -LiteralPath $Path).ToString()
    if ($null -eq $rel) {
        throw "Failed to resolve relative path for: $Path"
    }

    # Normalize to repo-relative, forward-slash paths (matches script/expected_parse_failures.txt)
    $rel = $rel -replace '^\.\\', ''
    $rel = $rel -replace '^\./', ''
    $rel = $rel -replace '\\', '/'

    return $rel
}

$repoRoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')
Set-Location $repoRoot

if (-not (Test-Path 'examples/astro')) {
    Write-Error "Missing examples/astro. If you cloned without submodules, run: git submodule update --init --depth 1 examples/astro"
    exit 1
}

$expectedParseFailures = Get-Content 'script/expected_parse_failures.txt' |
Where-Object { $_ -and ($_ -notmatch '^\s*#') } |
ForEach-Object { $_.Trim() } |
Where-Object { $_ }

foreach ($failure in $expectedParseFailures) {
    if (-not (Test-Path -LiteralPath $failure)) {
        Write-Error "Outdated script/expected_parse_failures.txt entry does not exist: $failure"
        exit 1
    }

    $null = & npx tree-sitter parse -q --grammar-path . $failure 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Error "Outdated script/expected_parse_failures.txt entry now parses successfully: $failure"
        exit 1
    }
}

$knownFailureSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($failure in $expectedParseFailures) {
    [void]$knownFailureSet.Add($failure)
}

$allFiles = Get-ChildItem -Path 'examples' -Recurse -File -Filter '*.astro'
$exampleCount = $allFiles.Count

$parsePaths = New-Object System.Collections.Generic.List[string]
foreach ($file in $allFiles) {
    $rel = Resolve-RepoRelativePath $file.FullName
    if ($knownFailureSet.Contains($rel)) {
        continue
    }

    $parsePaths.Add($rel)
}

$successCount = $parsePaths.Count

if ($successCount -eq 0) {
    Write-Error "No example files to parse (after excluding known failures)."
    exit 1
}

$tmp = New-TemporaryFile
try {
    Set-Content -Path $tmp.FullName -Value $parsePaths -Encoding utf8

    & npx tree-sitter parse -q --grammar-path . --paths $tmp.FullName
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Remove-Item -Force $tmp.FullName -ErrorAction SilentlyContinue
}

$successPercent = [Math]::Round((100.0 * $successCount / [Math]::Max(1, $exampleCount)), 1)
Write-Output ("Successfully parsed {0} of {1} example files ({2}%)" -f $successCount, $exampleCount, $successPercent)
