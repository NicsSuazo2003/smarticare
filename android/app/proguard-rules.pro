# Keep TensorFlow Lite (including GPU delegate) and FlatBuffers so R8 doesn't strip them
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class com.google.flatbuffers.** { *; }

# Optional: quiet warnings about optional/unused classes
-dontwarn org.tensorflow.**
-dontwarn com.google.flatbuffers.**