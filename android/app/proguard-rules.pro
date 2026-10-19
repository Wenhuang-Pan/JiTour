# Flutter 引擎与插件通道相关类
# WHY: Flutter 通过 JNI 反射调用引擎与插件注册类，混淆会破坏 MethodChannel 通信
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 应用原生代码全包保留
# WHY: MainActivity / OverlayService / NotificationListener / AccessibilityService
# 均由 AndroidManifest 或系统组件反射实例化，混淆将导致服务无法拉起
-keep class com.example.jitu.** { *; }

# WHY: mlkit_text_recognition 插件引用了中文/日文/韩文 OCR 类，
# 但这些 SDK 不在 dependencies 中，R8 报错。添加 -dontwarn 抑制警告。
# 拍照识别功能在用，此规则不可移除
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# WHY: Hive 序列化完全在 Dart 层完成（libapp.so），不涉及 Android 反射，
# 无需 keep 规则；此处无模型类属正常
