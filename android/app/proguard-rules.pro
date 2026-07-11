# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# SQLCipher
-keep class net.sqlcipher.** { *; }

# WorkManager
-keep class androidx.work.** { *; }

# Local Auth
-keep class com.example.personal_app.** { *; }

# Keep names of classes that use reflection
-keepnames class * implements java.io.Serializable

# Keep all enum values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}