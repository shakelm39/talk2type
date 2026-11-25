import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.voiceflow.ai.voiceflow_ai"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.voiceflow.ai.voiceflow_ai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = 35
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties").let { if (it.exists()) it else file("key.properties") }
    val keystoreProperties = Properties()
    val hasKeyProperties = keystorePropertiesFile.exists()
    if (hasKeyProperties) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    val envKeystorePath = System.getenv("T2T_KEYSTORE_PATH")
    val hasEnvKeystore = !envKeystorePath.isNullOrEmpty() && File(envKeystorePath).exists()

    signingConfigs {
        create("release") {
            if (hasKeyProperties) {
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                storeFile = if (storeFilePath != null) {
                    val f = File(storeFilePath)
                    if (f.isAbsolute) f else rootProject.file(storeFilePath)
                } else null
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            } else if (hasEnvKeystore) {
                storeFile = File(envKeystorePath)
                storePassword = System.getenv("T2T_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("T2T_KEY_ALIAS")
                keyPassword = System.getenv("T2T_KEY_PASSWORD")
            } else {
                logger.warn("*************************************************************************")
                logger.warn("WARNING: No release signing config found (key.properties or T2T_* env vars).")
                logger.warn("Falling back to DEBUG signing config for release build!")
                logger.warn("*************************************************************************")
                val debugConfig = signingConfigs.getByName("debug")
                storeFile = debugConfig.storeFile
                storePassword = debugConfig.storePassword
                keyAlias = debugConfig.keyAlias
                keyPassword = debugConfig.keyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
