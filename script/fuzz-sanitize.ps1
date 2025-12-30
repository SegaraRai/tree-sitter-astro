[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Iterations = 5000,
  [int]$Edits = 200,
  [switch]$NoRebuild,
  [string]$Include,
  [string]$Exclude,
  [switch]$LogGraphs,
  [switch]$Log,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$PassThruArgs
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command tree-sitter -ErrorAction SilentlyContinue)) {
  throw "tree-sitter CLI not found in PATH. Install via npm (e.g. npm i -D tree-sitter-cli) or ensure tree-sitter.exe is on PATH."
}

if (-not $env:CC) {
  $env:CC = 'clang'
}

$env:CFLAGS = '-O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined'
$env:LDFLAGS = '-fsanitize=address,undefined'

# On Windows, ASan-instrumented DLLs depend on clang_rt.asan_dynamic-x86_64.dll.
# Ensure the LLVM runtime directory is on PATH so the parser DLL can be loaded by tree-sitter fuzz.
try {
  $clangExe = (Get-Command clang -ErrorAction Stop).Source
  $clangBin = Split-Path -Parent $clangExe
  $asanDll = Get-ChildItem -Path (Join-Path $clangBin '..\lib\clang') -Recurse -Filter 'clang_rt.asan_dynamic-x86_64.dll' -ErrorAction SilentlyContinue |
  Select-Object -First 1

  if ($asanDll) {
    $asanDir = Split-Path -Parent $asanDll.FullName
    if ($env:PATH -notlike "$asanDir;*") {
      $env:PATH = "$asanDir;$env:PATH"
    }
  }
}
catch {
  # If clang isn't available, the fuzz run may still work without sanitizers.
}

if (-not $env:ASAN_OPTIONS) {
  $env:ASAN_OPTIONS = 'halt_on_error=1:abort_on_error=1:allocator_may_return_null=1'
}

$tsArgs = @('fuzz')
if (-not $NoRebuild) {
  $tsArgs += '--rebuild'
}

$tsArgs += @('--iterations', "$Iterations", '--edits', "$Edits")

if ($Include) {
  $tsArgs += @('--include', $Include)
}
if ($Exclude) {
  $tsArgs += @('--exclude', $Exclude)
}
if ($LogGraphs) {
  $tsArgs += '--log-graphs'
}
if ($Log) {
  $tsArgs += '--log'
}

if ($PassThruArgs) {
  $tsArgs += $PassThruArgs
}

& tree-sitter @tsArgs
exit $LASTEXITCODE
