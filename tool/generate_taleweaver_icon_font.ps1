<#
Generates the Taleweaver Office Ribbon icon font from the checked-in SVGs.

The source manifest deliberately permits only vectors from the local
ONLYOFFICE Document Editor toolbar reference. This script rejects raster
inputs, embedded images and provenance outside that root before calling
Fantasticon.

Usage (from repository root):
  powershell -ExecutionPolicy Bypass -File tool/generate_taleweaver_icon_font.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$iconsDirectory = Join-Path $repoRoot 'lib\assets\icons\taleweaver'
$fontsDirectory = Join-Path $repoRoot 'lib\assets\fonts'
$configPath = Join-Path $iconsDirectory 'fantasticon.config.js'
$manifestPath = Join-Path $iconsDirectory 'SOURCE_MANIFEST.json'

foreach ($requiredPath in @($iconsDirectory, $configPath, $manifestPath)) {
  if (-not (Test-Path -LiteralPath $requiredPath)) {
    throw "Required icon-font input is missing: $requiredPath"
  }
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$sourceRoot = [IO.Path]::GetFullPath([string]$manifest.permittedSourceRoot)
if (-not $sourceRoot.EndsWith([IO.Path]::DirectorySeparatorChar)) {
  $sourceRoot += [IO.Path]::DirectorySeparatorChar
}
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
  throw "ONLYOFFICE SVG source root is unavailable: $sourceRoot"
}

$rasterExtensions = @('.png', '.apng', '.gif', '.jpg', '.jpeg', '.webp', '.bmp', '.ico', '.avif')
$rasterInputs = Get-ChildItem -LiteralPath $iconsDirectory -Recurse -File |
  Where-Object { $rasterExtensions -contains $_.Extension.ToLowerInvariant() }
if ($rasterInputs) {
  $names = ($rasterInputs | ForEach-Object FullName) -join [Environment]::NewLine
  throw "Raster inputs are prohibited in the icon font source directory:`n$names"
}

$svgFiles = @(Get-ChildItem -LiteralPath $iconsDirectory -File -Filter '*.svg' | Sort-Object Name)
if ($svgFiles.Count -eq 0) {
  throw "No SVG inputs found in $iconsDirectory"
}

$manifestFiles = @($manifest.icons | ForEach-Object { [string]$_.file } | Sort-Object)
$actualFiles = @($svgFiles | ForEach-Object Name)
$differences = Compare-Object -ReferenceObject $manifestFiles -DifferenceObject $actualFiles
if ($differences) {
  $description = ($differences | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join ', '
  throw "SOURCE_MANIFEST.json and SVG inputs disagree: $description"
}

foreach ($icon in $manifest.icons) {
  $sourcePath = [IO.Path]::GetFullPath([string]$icon.sourcePath)
  if (-not $sourcePath.StartsWith($sourceRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Icon '$($icon.id)' has a source outside the permitted Document Editor toolbar root: $sourcePath"
  }
  if ([IO.Path]::GetExtension($sourcePath) -ne '.svg') {
    throw "Icon '$($icon.id)' source is not an SVG: $sourcePath"
  }
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Manifest source SVG is unavailable for '$($icon.id)': $sourcePath"
  }

  $outputPath = Join-Path $iconsDirectory ([string]$icon.file)
  $svg = Get-Content -LiteralPath $outputPath -Raw
  if ($svg -notmatch '(?is)<svg\b' -or
      $svg -match '(?is)<image\b|data:image|base64\s*,|\.(?:png|apng|gif|jpe?g|webp|bmp|ico|avif)\b') {
    throw "Output SVG '$($icon.file)' is not a standalone vector-only glyph."
  }
}

New-Item -ItemType Directory -Force -Path $fontsDirectory | Out-Null

Write-Host "Generating TaleweaverOfficeIcons from $($svgFiles.Count) vector SVG glyphs..."
Push-Location $repoRoot
try {
  # Fantasticon's config loader accepts this repository-relative, forward-slash
  # path on Windows more reliably than an absolute backslash path.
  & npx --yes fantasticon@1.2.3 --config 'lib/assets/icons/taleweaver/fantasticon.config.js'
} finally {
  Pop-Location
}
if ($LASTEXITCODE -ne 0) {
  throw "Fantasticon failed with exit code $LASTEXITCODE"
}

$expectedOutputs = @(
  'TaleweaverOfficeIcons.ttf',
  'TaleweaverOfficeIcons.woff',
  'TaleweaverOfficeIcons.woff2',
  'TaleweaverOfficeIcons.json'
)
foreach ($name in $expectedOutputs) {
  $output = Join-Path $fontsDirectory $name
  if (-not (Test-Path -LiteralPath $output -PathType Leaf) -or
      (Get-Item -LiteralPath $output).Length -le 0) {
    throw "Fantasticon did not generate a non-empty output: $output"
  }
}

$codepointMap = Get-Content -LiteralPath (Join-Path $fontsDirectory 'TaleweaverOfficeIcons.json') -Raw | ConvertFrom-Json
foreach ($icon in $manifest.icons) {
  $actual = $codepointMap.PSObject.Properties[[string]$icon.id]
  if ($null -eq $actual) {
    throw "Generated JSON map is missing '$($icon.id)'"
  }
  $expected = [Convert]::ToInt32([string]$icon.codepoint, 16)
  if ([int]$actual.Value -ne $expected) {
    throw "Unexpected codepoint for '$($icon.id)': $($actual.Value), expected $expected"
  }
}

Write-Host "Generated and validated: $($expectedOutputs -join ', ')"
