import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// WHY: 签名信息优先读取 android/key.properties（本地）或环境变量（GitHub Actions 注入）。
// 密码不再提供明文默认值；storeFile/keyAlias 非敏感保留默认。
// 缺失密码时不在配置阶段直接报错，以免阻断 analyze/test/debug 构建，
// 而是延迟到真正执行 release 打包任务时才快速失败。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun keystoreValue(propertyKey: String, envKey: String, defaultValue: String): String {
    return keystoreProperties.getProperty(propertyKey)
        ?: System.getenv(envKey)
        ?: defaultValue
}

fun keystoreSecret(propertyKey: String, envKey: String): String {
    return keystoreProperties.getProperty(propertyKey)
        ?: System.getenv(envKey)
        ?: ""
}

val releaseStorePassword = keystoreSecret("storePassword", "JITU_STORE_PASSWORD")
val releaseKeyPassword = keystoreSecret("keyPassword", "JITU_KEY_PASSWORD")

gradle.taskGraph.whenReady {
    val isReleaseBuild = allTasks.any { task ->
        task.name.startsWith("assemble") && task.name.contains("Release") ||
            task.name.startsWith("bundle") && task.name.contains("Release")
    }
    if (isReleaseBuild && (releaseStorePassword.isEmpty() || releaseKeyPassword.isEmpty())) {
        throw GradleException(
            "缺少 release 签名密码：请在 android/key.properties 配置 storePassword/keyPassword，" +
                "或通过环境变量 JITU_STORE_PASSWORD/JITU_KEY_PASSWORD 注入（CI 使用 GitHub Secrets）"
        )
    }
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
            keyAlias = keystoreValue("keyAlias", "JITU_KEY_ALIAS", "jitu")
            keyPassword = releaseKeyPassword
            storeFile = file(keystoreValue("storeFile", "JITU_STORE_FILE", "jitu.jks"))
            storePassword = releaseStorePassword
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
            // WHY: 开启 R8 代码压缩与资源收缩以缩减 APK 体积（dex 与未用资源是大头）。
            // 历史上因 mlkit 插件缺失类导致构建失败而关闭，现 proguard-rules.pro
            // 已补充 -dontwarn 规则抑制，且原生服务类已全包 keep，可安全开启。
            // mlkit OCR 拍照识别为高风险点，发版前需真机回归验证
            isMinifyEnabled = true
            isShrinkResources = true
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
