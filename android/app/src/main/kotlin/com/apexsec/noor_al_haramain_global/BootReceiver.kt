package com.apexsec.noor_al_haramain_global

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// ═══════════════════════════════════════════════════════════
/// 🔄 مستقبل إعادة تشغيل الهاتف
/// يعيد تشغيل التطبيق تلقائياً بعد إعادة تشغيل الهاتف
/// لكي يعود الإشعار الدائم للظهور
/// ═══════════════════════════════════════════════════════════
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launchIntent)
        }
    }
}
