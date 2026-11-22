$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$javaDirectory = $env:JAVA_HOME
if (-not $javaDirectory) { $javaDirectory = 'C:\Program Files\Android\Android Studio\jbr' }
$env:JAVA_HOME = $javaDirectory
$sdkDirectory = $env:ANDROID_HOME
if (-not $sdkDirectory) { $sdkDirectory = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$buildTools = Get-ChildItem (Join-Path $sdkDirectory 'build-tools') -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [Version]$_.Name } -Descending | Select-Object -First 1
if (-not $buildTools) { throw 'Install the Android SDK build tools or set ANDROID_HOME.' }
Push-Location $projectDirectory
try {
    & flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed. No new APK is ready to share.' }
    $apk = Join-Path $projectDirectory 'build\app\outputs\flutter-apk\app-release.apk'
    & (Join-Path $buildTools.FullName 'apksigner.bat') verify --verbose --print-certs $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed. Do not share this APK.' }
    & (Join-Path $buildTools.FullName 'zipalign.exe') -c -P 16 4 $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK alignment verification failed.' }
    $versionLine = Select-String -Path (Join-Path $projectDirectory 'pubspec.yaml') -Pattern '^version:\s*(\S+)'
    $appVersion = $versionLine.Matches[0].Groups[1].Value.Replace('+', '-build')
    $shareableApk = Join-Path $projectDirectory "build\app\outputs\flutter-apk\TalkMile-$appVersion-signed.apk"
    Copy-Item -LiteralPath $apk -Destination $shareableApk -Force
    Copy-Item -LiteralPath $apk -Destination (Join-Path (Split-Path $apk) 'talkmile.apk') -Force
    $hash = (Get-FileHash -LiteralPath $shareableApk -Algorithm SHA256).Hash
    [IO.File]::WriteAllText("$shareableApk.sha256", "$hash  $([IO.Path]::GetFileName($shareableApk))`n")
    Write-Output "Verified APK ready to share: $shareableApk"
} finally {
    Pop-Location
}
