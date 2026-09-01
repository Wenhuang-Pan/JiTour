plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.jitu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = "jitu"
            keyPassword = "Jitu2026"
            storeFile = file("jitu.jks")
            storePassword = "Jitu2026"
        }
    }

    defaultConfig {
        applicationId = "com.jitu.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // WHY: 关闭 R8 代码压缩，避免 mlkit 等插件缺失类导致构建失败
            // WHY: 保留 proguard-rules.pro 引用，未来需要混淆时可重新开启
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            applicationVariants.all {
                outputs.all {
                    this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
                    outputFileName = "记途_${defaultConfig.versionName}_release.apk"
                }
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
