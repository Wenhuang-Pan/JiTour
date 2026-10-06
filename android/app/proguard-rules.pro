# Flutter 默认混淆规则
# WHY: Flutter 应用默认不需要混淆，保留所有 Flutter 相关类
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# WHY: mlkit_text_recognition 插件引用了中文/日文/韩文 OCR 类，
# 但这些 SDK 不在 dependencies 中，R8 报错。添加 -dontwarn 抑制警告。
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# WHY: Hive 反射生成 TypeAdapter，需要保留模型类
-keep class com.example.jitu.models.** { *; }
-keep class com.example.jitu.** { *; }

# WHY: workmanager 需要保留 Worker 类
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker
