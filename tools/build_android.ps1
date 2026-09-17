<#
.SYNOPSIS
  Full build YOUR_ID_HERE: Kotlin plugin (AAR) -> Godot Android build template -> import -> export APK.

.EXAMPLE
  .\tools\build_android.ps1                # debug APK in build\YOUR_ID_HERE-debug.apk
  .\tools\build_android.ps1 -SkipPlugin    # don't rebuild AAR (only Godot export)
#>
param(
    [string]$GodotExe = "$env:USERPROFILE\Downloads\Godot463\Godot_v4.6.3-stable_win64_console.exe",
    [string]$JavaPath = "C:\Program Files\Eclipse Adoptium\jdk-17.0.20.8-hotspot",
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$GodotVersion = "4.6.3.stable",
    [switch]$SkipPlugin
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$buildPath = Join-Path $projectPath 'build'
$javaTemp = Join-Path $buildPath 'java-tmp'
$apkPath = Join-Path $buildPath 'YOUR_ID_HERE-debug.apk'
$templateZip = Join-Path $env:APPDATA "Godot\export_templates\$GodotVersion\android_source.zip"

foreach ($required in @($GodotExe, (Join-Path $JavaPath 'bin\java.exe'), $AndroidSdk, $templateZip)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing build dependency: $required" }
}
New-Item -ItemType Directory -Force -Path $javaTemp | Out-Null

$savedEnvironment = @{}
foreach ($name in @('JAVA_HOME','ANDROID_HOME','TEMP','TMP','JAVA_TOOL_OPTIONS')) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
    $env:JAVA_HOME = $JavaPath
    $env:ANDROID_HOME = $AndroidSdk
    $env:TEMP = $javaTemp
    $env:TMP = $javaTemp
    # Short ASCII paths: otherwise Java NIO sockets in Gradle fail in packaged shells.
    $env:JAVA_TOOL_OPTIONS = '-Djava.io.tmpdir="' + $javaTemp + '" -Djdk.net.unixdomain.tmpdir="' + $javaTemp + '"'

    # 1. Native plugin: JVM tests of pure logic + AAR -> addons/screenlingo/bin/*.aar
    if (-not $SkipPlugin) {
        Push-Location (Join-Path $projectPath 'android_plugin')
        try {
            # JVM writes "Picked up JAVA_TOOL_OPTIONS" to stderr; under Stop it would abort script.
            $ErrorActionPreference = 'Continue'
            & .\gradlew.bat :plugin:testDebugUnitTest copyToAddons --no-daemon --console=plain
            $ErrorActionPreference = 'Stop'
            if ($LASTEXITCODE -ne 0) { throw 'Native plugin build failed.' }
        } finally { Pop-Location }
    }

    # 2. Godot Android build template (same as "Project > Install Android Build Template").
    $androidDir = Join-Path $projectPath 'android'
    $androidBuild = Join-Path $androidDir 'build'
    $versionFile = Join-Path $androidDir '.build_version'
    $installed = (Test-Path -LiteralPath (Join-Path $androidBuild 'build.gradle')) -and
        (Test-Path -LiteralPath $versionFile) -and
        ((Get-Content -LiteralPath $versionFile -Raw).Trim() -eq $GodotVersion)
    if (-not $installed) {
        Write-Host "Installing Android build template $GodotVersion into android\build ..."
        if (Test-Path -LiteralPath $androidBuild) { Remove-Item -LiteralPath $androidBuild -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $androidBuild | Out-Null
        Expand-Archive -LiteralPath $templateZip -DestinationPath $androidBuild -Force
        New-Item -ItemType File -Force -Path (Join-Path $androidBuild '.gdignore') | Out-Null
        # Godot on Windows waits for child process to close: without this export "hangs" while daemon lives.
        Add-Content -LiteralPath (Join-Path $androidBuild 'gradle.properties') -Encoding utf8 -Value "`norg.gradle.daemon=false`n"
        Set-Content -LiteralPath $versionFile -Value $GodotVersion -Encoding ascii -NoNewline
    }

    # 3. Import resources (creates .godot/, *.uid) and export debug APK.
    $ErrorActionPreference = 'Continue'
    & $GodotExe --headless --path $projectPath --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
    & $GodotExe --headless --path $projectPath --export-debug Android $apkPath
    if ($LASTEXITCODE -ne 0) { throw 'Android export failed.' }
    $ErrorActionPreference = 'Stop'
    if (-not (Test-Path -LiteralPath $apkPath)) { throw "APK not produced: $apkPath" }
    Get-Item -LiteralPath $apkPath
} finally {
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
}
