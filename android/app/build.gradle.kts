import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Signing — loads from android/key.properties (local) or env vars (CI)
// ---------------------------------------------------------------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun signingProp(key: String): String? =
    (keystoreProperties[key] as? String)?.takeIf { it.isNotBlank() }
        ?: System.getenv(key.uppercase().replace('.', '_'))

val storeFilePath  = signingProp("storeFile")
val storePassword  = signingProp("storePassword")
val keyAlias       = signingProp("keyAlias")
val keyPassword    = signingProp("keyPassword")

val hasSigningConfig = listOf(storeFilePath, storePassword, keyAlias, keyPassword)
    .all { !it.isNullOrBlank() }

android {
    namespace = "com.example.sanchita"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.sanchita"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasSigningConfig) {
        signingConfigs {
            create("release") {
                storeFile     = file(storeFilePath!!)
                storePassword = this@Build_gradle.storePassword
                keyAlias      = this@Build_gradle.keyAlias
                keyPassword   = this@Build_gradle.keyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasSigningConfig)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all {
        outputs.all {
            (this as com.android.build.gradle.internal.api.BaseVariantOutputImpl)
                .outputFileName = "sanchita.apk"
        }
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-auth:20.7.0")
}

flutter {
    source = "../.."
}
