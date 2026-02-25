package com.paytrace.paytrace

import android.app.Notification
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.text.TextUtils
import android.util.Log

/**
 * Listens for UPI payment notifications from GPay, PhonePe, etc.
 *
 * When a payment notification arrives, it extracts the text and
 * sends it to Flutter via a static callback (which feeds into an EventChannel).
 *
 * Requires the user to grant Notification Access permission in Settings.
 */
class PaymentNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "PayTrace:NLS"

        // UPI app packages we monitor
        val MONITORED_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user",  // Google Pay
            "com.phonepe.app",                          // PhonePe
            "net.one97.paytm",                          // Paytm
            "in.org.npci.upiapp",                       // BHIM
            "com.whatsapp",                             // WhatsApp Pay
            "in.amazon.mShop.android.shopping",         // Amazon Pay
            "com.dreamplug.androidapp",                 // CRED
            "com.csam.icici.bank.imobile",              // iMobile Pay
            "com.mobikwik_new",                         // MobiKwik
        )

        /**
         * Static callback set by MainActivity when Flutter attaches.
         * Receives: Map<String, String> with keys: package, title, text, timestamp
         */
        var onNotificationReceived: ((Map<String, String>) -> Unit)? = null

        /**
         * Buffer for notifications received while Flutter isn't listening.
         * Drained when Flutter subscribes. Max 10 items.
         */
        private val pendingNotifications = mutableListOf<Map<String, String>>()

        /**
         * Drain and return all pending notifications (called from MainActivity on listen).
         */
        fun drainPending(): List<Map<String, String>> {
            val copy = pendingNotifications.toList()
            pendingNotifications.clear()
            return copy
        }

        /**
         * Check if notification listener permission is enabled.
         */
        fun isEnabled(context: android.content.Context): Boolean {
            val flat = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            )
            if (flat.isNullOrEmpty()) return false
            val names = flat.split(":")
            val myComponent = ComponentName(context, PaymentNotificationListener::class.java).flattenToString()
            val enabled = names.any { TextUtils.equals(it, myComponent) }
            Log.d(TAG, "isEnabled check: flat=$flat, myComponent=$myComponent, result=$enabled")
            return enabled
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "NotificationListenerService CREATED")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "NotificationListenerService CONNECTED — ready to receive notifications")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "NotificationListenerService DISCONNECTED")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName
        if (packageName !in MONITORED_PACKAGES) return

        try {
            val notification = sbn.notification ?: return
            val extras = notification.extras ?: return

            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""

            // Use bigText if available (more details), else text
            val content = if (bigText.isNotEmpty()) bigText else text

            if (content.isEmpty()) return

            Log.d(TAG, "★ Notification from $packageName: title=\"$title\", text=\"$content\"")

            val data = mapOf(
                "package" to packageName,
                "title" to title,
                "text" to content,
                "timestamp" to System.currentTimeMillis().toString()
            )

            val callback = onNotificationReceived
            if (callback != null) {
                Log.d(TAG, "→ Sending to Flutter via callback")
                callback.invoke(data)
            } else {
                Log.d(TAG, "→ Flutter not listening, buffering notification")
                synchronized(pendingNotifications) {
                    pendingNotifications.add(data)
                    // Keep only last 10
                    while (pendingNotifications.size > 10) {
                        pendingNotifications.removeAt(0)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification: ${e.message}")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Not needed for our use case
    }
}
