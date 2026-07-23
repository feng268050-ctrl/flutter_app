# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile
# 保留Apache Commons Logging核心类，防止被混淆/删除
-keep class org.apache.commons.logging.** { *; }
-keep class org.apache.commons.logging.impl.** { *; }

# 若还依赖commons-logging的其他实现（如android-logging-log4j），补充以下规则
-keep class android.util.Log { *; }
-keep class org.apache.log4j.** { *; }

# 确保LogFactory的反射调用不被破坏（ACL大量使用反射）
-keep class * implements org.apache.commons.logging.LogFactory {
    public <init>();
    public static org.apache.commons.logging.LogFactory getFactory();
}