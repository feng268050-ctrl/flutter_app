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
# ===================== 基础通用配置 =====================
# 保留Android核心组件
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# 保留自定义View关键方法
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
}

# 保留序列化/Parcelable相关
-keepclassmembers class * extends android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}
-keep class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    !private <fields>;
    !private <methods>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# 保留关键属性和native方法
-keepattributes *Annotation*, Signature, SourceFile, LineNumberTable, EnclosingMethod
-keepclasseswithmembernames class * { native <methods>; }
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# 优化配置：避免串口/Modbus反射/回调失效
-dontshrink
-dontoptimize

# ===================== 第三方库配置 =====================
# Retrofit + OkHttp + Okio
-keep interface * { @retrofit2.http.* <methods>; }
-keep class retrofit2.** { *; }
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okio.**
-dontwarn okhttp3.**
-dontwarn org.apache.commons.codec.binary.**

# Gson（替换为实际实体类包名）
-keep class com.google.gson.** { *; }
-keep class com.google.gson.annotations.** { *; }
-keep class your.package.model.** { *; }

# Kotlin协程
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Apache Commons Logging
-keep class org.apache.commons.logging.** { *; }
-keep class org.apache.commons.logging.impl.** { *; }
-keep class android.util.Log { *; }
-keep class org.apache.log4j.** { *; }
-keep class * implements org.apache.commons.logging.LogFactory {
    public <init>();
    public static org.apache.commons.logging.LogFactory getFactory();
}

# Modbus4j（核心规则）
-keep class com.serotonin.modbus4j.** { <fields>; <methods>; <init>(...); }
-keep interface com.serotonin.modbus4j.** { <methods>; }
-keep @com.serotonin.modbus4j.annotation.* class * { *; }
-keep class com.serotonin.modbus4j.msg.** extends com.serotonin.modbus4j.msg.ModbusRequest { *; }
-keep class com.serotonin.modbus4j.msg.** extends com.serotonin.modbus4j.msg.ModbusResponse { *; }
-keepclassmembers enum com.serotonin.modbus4j.code.FunctionCode { *; }
-keep class com.serotonin.modbus4j.exception.** { *; }
-keep class com.serotonin.modbus4j.serial.rtu.** { *; }
-keep class com.serotonin.modbus4j.serial.SerialMaster { *; }
-keepclassmembers class * {
    @com.serotonin.modbus4j.* <fields>;
    @com.serotonin.modbus4j.* <methods>;
}

# 串口SerialPort（替换为实际包名）
-keep class android.serialport.** { *; }
-keep class android.serialport.SerialPort {
    native <methods>;
    public <init>(java.io.File, int, int);
    public void close();
}

# Hutool + BouncyCastle
-keep class cn.hutool.crypto.** { *; }
-keep class cn.hutool.crypto.ProviderFactory {
    public static java.security.Provider createBouncyCastleProvider();
}
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# ===================== 业务代码保留 =====================
# 替换为实际调用串口/Modbus的业务类包名
-keep class com.lasercyber.lws.ui.** {
    public void *Modbus*(...);
    public void *Serial*(...);
}