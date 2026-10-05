[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$GroupNumber = 'G07',
    [string]$SourceRef = 'HEAD',
    [string]$ApkPath,
    [string]$OutputDir = (Join-Path $PSScriptRoot '..\submission_packages')
)
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputRoot = [IO.Path]::GetFullPath($OutputDir)
if (-not $outputRoot.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The package output must be inside the project workspace.'
}
$commit = (& git -C $repoRoot rev-parse --verify "$SourceRef^{commit}").Trim()
if ($LASTEXITCODE -ne 0) { throw 'SourceRef must identify a real Git commit.' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$packageName = "SE3090_$GroupNumber"
$stage = Join-Path $outputRoot "$packageName-$stamp"
if (Test-Path -LiteralPath $stage) { throw 'Output already exists; choose a new output directory.' }
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$sourceZip = Join-Path $stage 'committed-source.zip'
& git -C $repoRoot archive --format=zip "--output=$sourceZip" $commit
if ($LASTEXITCODE -ne 0) { throw 'git archive failed.' }
$sourceDir = Join-Path $stage 'Source_Code'
Expand-Archive -LiteralPath $sourceZip -DestinationPath $sourceDir
Remove-Item -LiteralPath $sourceZip
Copy-Item -LiteralPath (Join-Path $sourceDir 'docs') -Destination (Join-Path $stage 'Documentation') -Recurse
if (-not [string]::IsNullOrWhiteSpace($ApkPath)) {
    $apk = (Resolve-Path -LiteralPath $ApkPath).Path
    if ([IO.Path]::GetExtension($apk) -ne '.apk') { throw 'ApkPath must name an APK.' }
    $mobileDir = Join-Path $stage 'Mobile_APK'
    New-Item -ItemType Directory -Path $mobileDir | Out-Null
    Copy-Item -LiteralPath $apk -Destination (Join-Path $mobileDir 'BuildWise.apk')
}
$manifest = @"
BuildWise - $packageName
Created: $stamp
Source commit: $commit
Repository: https://github.com/IT24102414/build
Source is taken exclusively from the named Git commit.
Ignored local environments, credentials, runtime logs and virtual environments are excluded.
Historical root APK is excluded by .gitattributes; pass -ApkPath with a verified current release.
Consolidated report draft: Documentation/submission-report.md
Readiness checklist: Documentation/submission-readiness.md
Complete student-owned reflections, signatures, deployment URLs and video before submission.
This package does not certify a deadline submission, deployment or APK device validation.
"@
Set-Content -LiteralPath (Join-Path $stage 'SUBMISSION_MANIFEST.txt') -Value $manifest -Encoding UTF8
$zip = Join-Path $outputRoot "$packageName-$stamp.zip"
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
Write-Output "Package created: $zip"
Write-Output "Source commit: $commit"
