# TensorFlow Lite — keep GPU delegate classes referenced at runtime
-dontwarn org.tensorflow.lite.gpu.**
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.** { *; }
