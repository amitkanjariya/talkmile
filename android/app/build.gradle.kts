import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = System.getenv("TALKMILE_SIGNING_PROPERTIES")
    ?.let { file(it) }
    ?: File(System.getProperty("user.home"), ".talkmile/signing/key.properties")
val signingProperties = Properties().apply {
    if (signingPropertiesFile.isFile) {
        signingPropertiesFile.inputStream().use { load(it) }
    }
}
fun signingValue(environmentName: String, propertyName: String): String? =
    System.getenv(environmentName)?.takeIf { it.isNotBlank() }
        ?: signingProperties.getProperty(propertyName)

val releaseKeystorePath = signingValue("TALKMILE_KEYSTORE", "storeFile")
val releaseStorePassword = signingValue("TALKMILE_STORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingValue("TALKMILE_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingValue("TALKMILE_KEY_PASSWORD", "keyPassword")
val releaseSigningReady = listOf(
    releaseKeystorePath, releaseStorePassword, releaseKeyAlias, releaseKeyPassword
).all { !it.isNullOrBlank() }

android {
    namespace = "com.talkmile.talkmile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.talkmile.talkmile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

// A successful Flutter build must never silently produce an unsigned release.
val validateReleaseSigning by tasks.registering {
    doLast {
        check(releaseSigningReady) {
            "Release signing is missing. Run tool/setup-release-signing.ps1 once, " +
                "or configure TALKMILE_SIGNING_PROPERTIES / TALKMILE signing environment variables."
        }
        check(file(releaseKeystorePath!!).isFile) { "Release keystore file was not found." }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseSigning)
}
