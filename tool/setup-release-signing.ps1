$ErrorActionPreference = 'Stop'
$signingDirectory = Join-Path $env:USERPROFILE '.talkmile\signing'
$propertiesFile = Join-Path $signingDirectory 'key.properties'
$keystoreFile = Join-Path $signingDirectory 'talkmile-release.p12'
if ((Test-Path -LiteralPath $propertiesFile) -or (Test-Path -LiteralPath $keystoreFile)) {
    throw 'Signing material already exists. Reuse it; do not replace the key used by installed releases.'
}
$javaDirectory = $env:JAVA_HOME
if (-not $javaDirectory) { $javaDirectory = 'C:\Program Files\Android\Android Studio\jbr' }
$keytool = Join-Path $javaDirectory 'bin\keytool.exe'
if (-not (Test-Path -LiteralPath $keytool)) { throw 'Set JAVA_HOME to your JDK directory.' }
New-Item -ItemType Directory -Force -Path $signingDirectory | Out-Null
# Restrict locally stored credentials to the current Windows user.
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = [System.Security.AccessControl.DirectorySecurity]::new()
$acl.SetOwner($identity)
$acl.SetAccessRuleProtection($true, $false)
$rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
    $identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.AddAccessRule($rule)
Set-Acl -LiteralPath $signingDirectory -AclObject $acl
$randomBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($randomBytes)
$rng.Dispose()
$password = [Convert]::ToBase64String($randomBytes)
# Secrets are passed through the child environment, never command arguments.
$env:TALKMILE_GENERATED_STORE_PASSWORD = $password
try {
    & $keytool -genkeypair -noprompt -storetype PKCS12 -keystore $keystoreFile `
        -alias talkmile -keyalg RSA -keysize 3072 -validity 10000 `
        -dname 'CN=TalkMile, O=TalkMile, C=IN' `
        -storepass:env TALKMILE_GENERATED_STORE_PASSWORD `
        -keypass:env TALKMILE_GENERATED_STORE_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the release signing key.' }
    $forwardPath = $keystoreFile.Replace('\', '/')
    $properties = "storeFile=$forwardPath`nstorePassword=$password`nkeyAlias=talkmile`nkeyPassword=$password`n"
    [IO.File]::WriteAllText($propertiesFile, $properties, [Text.UTF8Encoding]::new($false))
} finally {
    Remove-Item Env:TALKMILE_GENERATED_STORE_PASSWORD -ErrorAction SilentlyContinue
    $password = $null
}
Write-Output "Release signing is ready. Back up this private directory securely: $signingDirectory"
