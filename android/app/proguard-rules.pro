# shared_preferences_android 2.5+ calls Kotlin over JNI (package:jni), looking up these
# classes, members and method descriptors by name. Without these rules R8 renames or
# strips them and release builds fail with NoSuchMethodError/ClassNotFoundException.
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.** { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.Unit { *; }
-keepnames class kotlin.enums.EnumEntries
-keepnames class kotlin.jvm.internal.DefaultConstructorMarker
