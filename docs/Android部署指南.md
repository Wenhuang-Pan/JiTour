# 记途 Android 部署指南

## 当前状态

✅ **已完成**：
- Android CLI 工具已下载到 `C:\Users\pwh15\AppData\Local\Android\Sdk\android.exe`
- 环境变量已设置（ANDROID_HOME、JAVA_HOME）
- Flutter 已配置 Android SDK 路径
- Android 项目目录已重新生成（修复了 Gradle 问题）
- Java JDK 17 已安装：`C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot`

⏳ **待完成**（需要管理员权限）：
- 安装 SDK 组件（platform-tools、build-tools、platforms）
- 构建 APK

---

## 一、一键完成所有步骤（管理员 PowerShell）

### 打开管理员 PowerShell
1. 右键点击 Windows 开始按钮
2. 选择 **"Windows PowerShell (管理员)"** 或 **"终端(管理员)"**
3. 点击 "是" 授权

### 复制粘贴以下命令（全部一次性执行）：

```powershell
# 设置环境变量
$env:ANDROID_HOME = "$env:USERPROFILE\AppData\Local\Android\Sdk"
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot"
$env:Path += ";$env:ANDROID_HOME;$env:ANDROID_HOME\platform-tools;$env:JAVA_HOME\bin"
$sdkPath = "$env:USERPROFILE\AppData\Local\Android\Sdk"

# 安装 SDK 组件
Write-Host "正在安装 SDK 组件..."
& "$sdkPath\android.exe" sdk install platform-tools
& "$sdkPath\android.exe" sdk install build-tools
& "$sdkPath\android.exe" sdk install platforms@34

# 验证安装
Write-Host "验证配置..."
java -version
flutter doctor

# 构建 APK
Write-Host "正在构建 APK..."
cd "F:\AI Programme\00 SimpleLedger"
flutter build apk --release

Write-Host "完成！APK 位于：build\app\outputs\flutter-apk\app-release.apk"
```

**预计时间**：10-15 分钟（下载 SDK + 构建 APK）

---

## 二、APK 安装到手机

### 方法 1：USB传输
1. 将 `app-release.apk` 复制到手机
2. 在手机上点击安装
3. 如提示"未知来源"，在设置中开启权限

### 方法 2：微信/QQ传输
1. 发送 APK 到"文件传输助手"
2. 在手机上接收并安装

---

## 三、云盘同步配置

**备份文件位置**：
```
手机存储/SimpleLedger_Backups/
```

**推荐云盘**：
- Google Drive（免费15GB）
- OneDrive（免费5GB）
- Dropbox（免费2GB）

**配置步骤**：
1. 安装云盘应用
2. 开启自动同步
3. 添加 `SimpleLedger_Backups` 目录

---

## 已解决的问题

### Gradle 项目不兼容问题 ✅
- **原因**：项目缺少 android 目录
- **解决**：使用 `flutter create --platforms=android .` 重新生成
- **状态**：已修复

### JAVA_HOME 未设置 ✅
- **原因**：构建 Gradle 需要 Java JDK
- **解决**：安装 Microsoft OpenJDK 17 并设置环境变量
- **状态**：已修复，JAVA_HOME = `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot`

---

**最后更新**：2026-06-25 21:25
