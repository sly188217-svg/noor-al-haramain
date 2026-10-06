package com.apexsec.noor_al_haramain_global

import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.InetSocketAddress
import java.net.Socket
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.apexsec.noor/security"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "verifySignature" -> result.success(verifySignature())
                    "isDebuggerAttached" -> result.success(isDebuggerAttached())
                    "isFridaRunning" -> result.success(isFridaRunning())
                    "isEmulator" -> result.success(isEmulator())
                    "isRooted" -> result.success(isRooted())
                    "getSignatureHash" -> result.success(getSignatureHash())
                    else -> result.notImplemented()
                }
            }
    }

    // ═══════════════════════════════════════════════════════════
    // 🔐 1) التحقق من التوقيع
    // ═══════════════════════════════════════════════════════════
    private fun verifySignature(): Boolean {
        return try {
            val currentHash = getSignatureHash()
            if (currentHash.isEmpty()) {
                Log.e("Security", "❌ لا يوجد توقيع!")
                return false
            }

            val expectedHash = BuildConfig.EXPECTED_SIGNATURE

            Log.d("Security", "توقيع APK: $currentHash")
            Log.d("Security", "المتوقع:  $expectedHash")

            // إذا لم يُحدَّث بعد، اقبل أي توقيع
            if (expectedHash == "PLACEHOLDER_UPDATE_AFTER_BUILD") {
                Log.w("Security", "⚠️ EXPECTED_SIGNATURE لم يُحدَّث بعد")
                return true
            }

            currentHash.equals(expectedHash, ignoreCase = true)
        } catch (e: Exception) {
            Log.e("Security", "❌ فشل التحقق: ${e.message}")
            false
        }
    }

    private fun getSignatureHash(): String {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
            }

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }

            if (signatures == null || signatures.isEmpty()) return ""

            val md = MessageDigest.getInstance("SHA-256")
            val hash = md.digest(signatures[0].toByteArray())
            hash.joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            Log.e("Security", "❌ getSignatureHash: ${e.message}")
            ""
        }
    }

    // ═══════════════════════════════════════════════════════════
    // 🐛 2) كشف Debugger
    // ═══════════════════════════════════════════════════════════
    private fun isDebuggerAttached(): Boolean {
        if (Debug.isDebuggerConnected()) {
            Log.e("Security", "🚨 Debugger متصل!")
            return true
        }

        try {
            val reader = BufferedReader(
                InputStreamReader(File("/proc/self/status").inputStream())
            )
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                if (line!!.startsWith("TracerPid:")) {
                    val pid = line!!.substring(10).trim().toInt()
                    if (pid != 0) {
                        Log.e("Security", "🚨 TracerPid = $pid")
                        reader.close()
                        return true
                    }
                }
            }
            reader.close()
        } catch (e: Exception) {
            Log.e("Security", "⚠️ TracerPid: ${e.message}")
        }

        return false
    }

    // ═══════════════════════════════════════════════════════════
    // 🐍 3) كشف Frida / Xposed
    // ═══════════════════════════════════════════════════════════
    private fun isFridaRunning(): Boolean {
        // 1) فحص ملفات Frida
        val suspicious = listOf(
            "/data/local/tmp/frida-server",
            "/data/local/tmp/re.frida.server",
            "/data/local/tmp/frida",
            "/sdcard/frida-server",
            "/system/lib/libfrida-gadget.so",
            "/system/lib64/libfrida-gadget.so",
            "/system/framework/XposedBridge.jar"
        )

        for (path in suspicious) {
            if (File(path).exists()) {
                Log.e("Security", "🐍 Frida/Xposed: $path")
                return true
            }
        }

        // 2) فحص /proc/self/maps
        try {
            val reader = BufferedReader(
                InputStreamReader(File("/proc/self/maps").inputStream())
            )
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                val lower = line!!.lowercase()
                if (lower.contains("frida") ||
                    lower.contains("xposed") ||
                    lower.contains("substrate")
                ) {
                    Log.e("Security", "🐍 مكتبة مشبوهة: $line")
                    reader.close()
                    return true
                }
            }
            reader.close()
        } catch (e: Exception) {
            Log.e("Security", "⚠️ maps: ${e.message}")
        }

        // 3) فحص المنفذ 27042
        try {
            val socket = Socket()
            socket.connect(InetSocketAddress("127.0.0.1", 27042), 100)
            socket.close()
            Log.e("Security", "🐍 منفذ Frida 27042!")
            return true
        } catch (_: Exception) {
            // طبيعي
        }

        return false
    }

    // ═══════════════════════════════════════════════════════════
    // 🖥️ 4) كشف Emulator
    // ═══════════════════════════════════════════════════════════
    private fun isEmulator(): Boolean {
        val indicators = listOf(
            Build.FINGERPRINT.startsWith("generic"),
            Build.FINGERPRINT.startsWith("unknown"),
            Build.FINGERPRINT.contains("test-keys"),
            Build.MODEL.contains("google_sdk"),
            Build.MODEL.contains("Emulator"),
            Build.MODEL.contains("Android SDK built for"),
            Build.MANUFACTURER.contains("Genymotion"),
            Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"),
            Build.PRODUCT == "google_sdk",
            Build.HARDWARE.contains("goldfish"),
            Build.HARDWARE.contains("ranchu"),
            Build.HARDWARE.contains("vbox"),
            Build.HARDWARE.contains("qemu")
        )

        return indicators.any { it }
    }

    // ═══════════════════════════════════════════════════════════
    // 🔓 5) كشف Root
    // ═══════════════════════════════════════════════════════════
    private fun isRooted(): Boolean {
        val suPaths = listOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/system/su",
            "/system/bin/.ext/su",
            "/system/usr/we-need-root/su",
            "/system/app/Superuser.apk",
            "/system/app/SuperSU.apk",
            "/data/local/su",
            "/data/local/bin/su",
            "/data/local/xbin/su",
            "/magisk/.core/bin/su"
        )

        for (path in suPaths) {
            if (File(path).exists()) {
                Log.e("Security", "🔓 Root: $path")
                return true
            }
        }

        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            Log.e("Security", "🔓 test-keys")
            return true
        }

        return false
    }
}
