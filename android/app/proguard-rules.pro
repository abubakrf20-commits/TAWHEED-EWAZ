# ══════════════════════════════════════════════════════════════
# ProGuard / R8 Rules — Tawheed App
# Complete rules for all plugins and native classes
# ══════════════════════════════════════════════════════════════

# ── Global Settings ──
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep enum values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ══════════════════════════════════════════════════════════════
# FLUTTER CORE
# ══════════════════════════════════════════════════════════════
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── Flutter Engine — Explicit keeps for classes R8 full mode strips ──
# Without these, users see on some devices (especially cold-boot / low-RAM):
#   NPE: FlutterApplicationInfo.flutterAssetsDir on null object
#   at FlutterLoader.findAppBundlePath()
-keep class io.flutter.embedding.engine.loader.FlutterApplicationInfo {
    <init>(android.content.Context,android.content.pm.ApplicationInfo);
    <fields>;
}
-keep class io.flutter.embedding.engine.loader.FlutterLoader {
    <methods>;
    <fields>;
}
-keepclassmembers class io.flutter.embedding.engine.FlutterJNI { *; }

# Keep all Flutter plugin registrants
-keep class io.flutter.plugin.common.** { *; }
-dontwarn io.flutter.plugin.common.**

# ══════════════════════════════════════════════════════════════
# APP'S NATIVE KOTLIN CLASSES (referenced from manifest + MethodChannel)
# ══════════════════════════════════════════════════════════════
-keep class com.islamic.tawheeed.MainActivity { *; }
-keep class com.islamic.tawheeed.AzanForegroundService { *; }

# All core classes (receivers, schedulers, helpers)
-keep class com.islamic.tawheeed.core.** { *; }
-keepclassmembers class com.islamic.tawheeed.core.** { *; }

# All widget classes (AppWidgetProviders + RemoteViews)
-keep class com.islamic.tawheeed.widget.** { *; }
-keepclassmembers class com.islamic.tawheeed.widget.** { *; }

# PrayerWidget — explicit keep (referenced from AndroidManifest)
-keep class com.islamic.tawheeed.widget.PrayerWidget { *; }
-keepclassmembers class com.islamic.tawheeed.widget.PrayerWidget { *; }
-keep class com.islamic.tawheeed.widget.PrayerWidget$Companion { *; }

# TasbihGlanceWidgetReceiver — explicit keep
-keep class com.islamic.tawheeed.widget.TasbihGlanceWidgetReceiver { *; }
-keepclassmembers class com.islamic.tawheeed.widget.TasbihGlanceWidgetReceiver { *; }

# Keep all AppWidgetProvider subclasses (referenced from AndroidManifest)
-keep,allowobfuscation class * extends android.appwidget.AppWidgetProvider

# Keep all BroadcastReceiver subclasses
-keep,allowobfuscation class * extends android.content.BroadcastReceiver

# Keep all Service subclasses
-keep,allowobfuscation class * extends android.app.Service

# ══════════════════════════════════════════════════════════════
# ANDROID RESOURCES (R class — referenced from native code)
# ══════════════════════════════════════════════════════════════
-keep class com.islamic.tawheeed.R { *; }
-keep class com.islamic.tawheeed.R$** { *; }
-keepclassmembers class **.R$* { *; }
-keepclassmembers class **.R$raw { *; }
-keepclassmembers class **.R$xml { *; }
-keepclassmembers class **.R$drawable { *; }
-keepclassmembers class **.R$mipmap { *; }

# ══════════════════════════════════════════════════════════════
# ANDROIDX
# ══════════════════════════════════════════════════════════════

# AndroidX Core
-keep class androidx.core.** { *; }
-dontwarn androidx.core.**

# AndroidX Lifecycle
-keep class * extends androidx.lifecycle.ViewModel
-keep class * extends androidx.lifecycle.AndroidViewModel
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# AndroidX WorkManager (critical for background tasks)
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker
-keep class * extends androidx.work.CoroutineWorker
-keepclassmembers class * extends androidx.work.ListenableWorker {
    public <init>(...);
}
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# AndroidX Collection
-keep class androidx.collection.** { *; }
-dontwarn androidx.collection.**

# AndroidX Annotation
-keep class androidx.annotation.** { *; }
-dontwarn androidx.annotation.**

# ══════════════════════════════════════════════════════════════
# FLUTTER PLUGINS — Complete coverage
# ══════════════════════════════════════════════════════════════

# ── flutter_local_notifications ──
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# ── adhan (Prayer Times) ──
-keep class com.batoulapps.adhan.** { *; }
-keep class com.batoulapps.adhan.internal.** { *; }
-keep class com.github.kizitonwoser.time.** { *; }
-dontwarn com.batoulapps.adhan.**
-dontwarn com.github.kizitonwoser.time.**

# ── geolocator ──
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ── geocoding ──
-keep class com.baseflow.geocoding.** { *; }
-dontwarn com.baseflow.geocoding.**

# ── flutter_compass ──
-keep class com.hukumdar.** { *; }
-keep class io.flutter.plugins.compass.** { *; }
-dontwarn com.hukumdar.**
-dontwarn io.flutter.plugins.compass.**

# ── shared_preferences ──
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── flutter_secure_storage ──
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# ── path_provider ──
-keep class io.flutter.plugins.pathprovider.** { *; }

# ── url_launcher ──
-keep class io.flutter.plugins.urllauncher.** { *; }

# ── share_plus ──
-keep class dev.fluttercommunity.plus.share.** { *; }

# ── package_info_plus ──
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# ── device_info_plus ──
-keep class dev.fluttercommunity.plus.deviceinfo.** { *; }

# ── connectivity_plus ──
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ── wakelock_plus ──
-keep class dev.fluttercommunity.plus.wakelock.** { *; }

# ── audioplayers ──
-keep class io.flutter.plugins.audioplayers.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# ── Native background scheduler ──
-keep class com.islamic.tawheeed.core.NativeBackgroundScheduler { *; }
-keep class com.islamic.tawheeed.core.NativeBackgroundWorker { *; }

# ── drift (Database) ──
-keep class com.drift.** { *; }
-keep class drift.** { *; }
-dontwarn com.drift.**
-dontwarn drift.**

# ── sqlite3_flutter_libs (native sqlite3) ──
-keep class org.teaave.** { *; }
-keep class org.sqlite.** { *; }
-dontwarn org.teaave.**
-dontwarn org.sqlite.**

# ── Gson (used by various plugins) ──
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ── Shamsi Date ──
-keep class com.razaghmehshiraziflutter.shamsidate.** { *; }

# ── Flutter Riverpod (code-generated) ──
-keep class **.g.dart { *; }

# ── GoRouter (code-generated) ──
-keep class **.g.dart { *; }

# ══════════════════════════════════════════════════════════════
# JAVA / KOTLIN STANDARD LIBRARY
# ══════════════════════════════════════════════════════════════
-keep class java.lang.** { *; }
-keep class java.util.** { *; }
-keep class java.io.** { *; }
-keep class java.net.** { *; }
-keep class javax.** { *; }
-dontwarn javax.**
-dontwarn java.**

# ── Kotlin Coroutines ──
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ── Kotlin Serialization ──
-keep class kotlinx.serialization.** { *; }
-dontwarn kotlinx.serialization.**

# ── OkHttp (used by http package) ──
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Android JSON ──
-keep class org.json.** { *; }

# ══════════════════════════════════════════════════════════════
# CRASH PREVENTION — Common R8 pitfalls
# ══════════════════════════════════════════════════════════════

# Keep all classes with native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all classes that implement InvocationHandler (for proxies)
-keep class * implements java.lang.reflect.InvocationHandler { *; }

# Keep all @Keep annotated classes
-keep @androidx.annotation.Keep class * { *; }

# Keep all classes referenced by AndroidManifest
-keep class * extends android.app.Activity
-keep class * extends android.app.Application
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver
-keep class * extends android.content.ContentProvider
-keep class * extends android.appwidget.AppWidgetProvider

# Keep MethodChannel communication
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class io.flutter.plugin.common.MethodChannel$Result { *; }

# Keep EventChannel communication
-keep class io.flutter.plugin.common.EventChannel { *; }
-keep class io.flutter.plugin.common.EventChannel$EventSink { *; }
-keep class io.flutter.plugin.common.EventChannel$StreamHandler { *; }

# Prevent R8 from stripping MethodChannel handler classes
-keepattributes InnerClasses
-keep class **$Companion { *; }

# Keep Flutter plugin classes
-keep class io.flutter.plugins.** { *; }
