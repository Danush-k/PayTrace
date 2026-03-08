package com.paytrace.paytrace

import android.app.Notification
import android.content.ComponentName
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.text.TextUtils
import android.util.Log
import java.util.concurrent.ConcurrentHashMap
import java.util.regex.Pattern

/**
 * PaymentNotificationListener — NotificationListenerService
 *
 * Captures payment notifications from UPI apps, parses them natively,
 * deduplicates within a 60-second window, and forwards structured data
 * to Flutter via a static callback that feeds an EventChannel.
 *
 * ── Monitoring ────────────────────────────────────────────────────────
 * Primary (required) packages:
 *   • com.google.android.apps.nbu.paisa.user  (Google Pay)
 *   • com.phonepe.app                          (PhonePe)
 *   • net.one97.paytm                          (Paytm)
 *   • in.amazon.mShop.android.shopping         (Amazon Pay)
 *
 * Extended packages (also monitored):
 *   • in.org.npci.upiapp   (BHIM)
 *   • com.whatsapp          (WhatsApp Pay)
 *   • com.dreamplug.androidapp (CRED)
 *   • com.csam.icici.bank.imobile (iMobile Pay)
 *   • com.mobikwik_new      (MobiKwik)
 *
 * ── Parsed fields ─────────────────────────────────────────────────────
 * Kotlin parses and populates additional keys alongside raw text:
 *   parsed_amount   — monetary value as string ("250.0")
 *   parsed_merchant — payee / payer name
 *   parsed_type     — "expense" or "income"
 *
 * ── Deduplication ────────────────────────────────────────────────────
 * Two notifications with the same (package, amount, type) within
 * DEDUP_WINDOW_MS (60 s) are considered duplicates and discarded.
 *
 * Requires the user to grant Notification Access permission in Settings.
 */
class PaymentNotificationListener : NotificationListenerService() {

    // ─────────────────────────────────────────────────────────────────
    companion object {
        private const val TAG = "PayTrace:NLS"

        /** 60-second dedup window (milliseconds). */
        private const val DEDUP_WINDOW_MS = 60_000L

        // ── Required packages (from spec) ──
        private val REQUIRED_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user",   // Google Pay
            "com.phonepe.app",                           // PhonePe
            "net.one97.paytm",                           // Paytm
            "in.amazon.mShop.android.shopping",          // Amazon Pay
        )

        // ── Extended package set (all monitored) ──
        val MONITORED_PACKAGES = REQUIRED_PACKAGES + setOf(
            "in.org.npci.upiapp",                        // BHIM
            "com.whatsapp",                              // WhatsApp Pay
            "com.dreamplug.androidapp",                  // CRED
            "com.csam.icici.bank.imobile",               // iMobile Pay
            "com.mobikwik_new",                          // MobiKwik
        )

        /**
         * Static callback set by MainActivity when Flutter EventChannel attaches.
         * Receives Map<String, String> with keys:
         *   package, title, text, timestamp,
         *   parsed_amount, parsed_merchant, parsed_type
         */
        var onNotificationReceived: ((Map<String, String>) -> Unit)? = null

        /**
         * Buffer for notifications received while Flutter isn't listening.
         * Drained on EventChannel subscribe. Capped at 20 items.
         */
        private val pendingNotifications = mutableListOf<Map<String, String>>()

        /**
         * In-memory dedup register.
         * Key  : "${packageName}::${formattedAmount}::${type}"
         * Value: epoch-ms of last event with that key
         */
        private val dedupCache = ConcurrentHashMap<String, Long>()

        fun drainPending(): List<Map<String, String>> {
            val copy = synchronized(pendingNotifications) { pendingNotifications.toList() }
            synchronized(pendingNotifications) { pendingNotifications.clear() }
            return copy
        }

        fun isEnabled(context: android.content.Context): Boolean {
            val flat = Settings.Secure.getString(
                context.contentResolver, "enabled_notification_listeners"
            )
            if (flat.isNullOrEmpty()) return false
            val myComp = ComponentName(
                context, PaymentNotificationListener::class.java
            ).flattenToString()
            val enabled = flat.split(":").any { TextUtils.equals(it, myComp) }
            Log.d(TAG, "isEnabled=$enabled")
            return enabled
        }
    }

    // ─────────────────────────────────────────────────────────────────
    //  Lifecycle
    // ─────────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "NLS CREATED")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "NLS CONNECTED — ready")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "NLS DISCONNECTED")
    }

    // ─────────────────────────────────────────────────────────────────
    //  Main entry point
    // ─────────────────────────────────────────────────────────────────

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        if (pkg !in MONITORED_PACKAGES) return

        try {
            val extras = sbn.notification?.extras ?: return

            val title    = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()    ?: ""
            val text     = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()     ?: ""
            val bigText  = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
            val content  = if (bigText.isNotEmpty()) bigText else text

            if (content.isEmpty() && title.isEmpty()) return

            val combined = "$title $content"
            Log.d(TAG, "★ Notification from $pkg: title=\"$title\" text=\"$content\"")

            // ── Native parse ──
            val amount   = NotificationParser.parseAmount(combined)
            val merchant = NotificationParser.parseMerchant(combined)
            val type     = NotificationParser.parseType(combined)

            // Must have a detectable payment amount to be useful
            if (amount == null) {
                Log.d(TAG, "Skip — no amount detected in: $combined")
                return
            }

            val nowMs = System.currentTimeMillis()

            // ── 60-second dedup ──
            val dedupKey = "$pkg::${amount}::$type"
            val lastSeen = dedupCache[dedupKey]
            if (lastSeen != null && (nowMs - lastSeen) < DEDUP_WINDOW_MS) {
                Log.d(TAG,
                    "DEDUP — skipping duplicate $type ₹$amount from $pkg " +
                    "(last seen ${nowMs - lastSeen}ms ago)"
                )
                return
            }
            dedupCache[dedupKey] = nowMs

            // Evict old entries from the cache (keep memory bounded)
            if (dedupCache.size > 200) {
                val cutoff = nowMs - DEDUP_WINDOW_MS * 5
                dedupCache.entries.removeAll { it.value < cutoff }
            }

            val data = buildMap {
                put("package",          pkg)
                put("title",            title)
                put("text",             content)
                put("timestamp",        nowMs.toString())
                put("parsed_amount",    amount.toString())
                put("parsed_merchant",  merchant ?: "")
                put("parsed_type",      type)
            }

            Log.d(TAG, "→ Parsed: $type ₹$amount → ${merchant ?: "unknown"}")

            val callback = onNotificationReceived
            if (callback != null) {
                Log.d(TAG, "→ Forwarding to Flutter")
                callback.invoke(data)
            } else {
                Log.d(TAG, "→ Buffering (Flutter not yet listening)")
                synchronized(pendingNotifications) {
                    pendingNotifications.add(data)
                    while (pendingNotifications.size > 20) pendingNotifications.removeAt(0)
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification from $pkg: ${e.message}")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Not needed
    }
}

// ═════════════════════════════════════════════════════════════════════
//  NotificationParser
//
//  Extracts structured data from UPI payment notification strings.
//
//  Handles the patterns required by spec:
//    "₹250 paid to Swiggy"
//    "Paid ₹150 to Rahul"
//    "Received ₹500 from Arjun"
//  Plus common variations from each supported app.
// ═════════════════════════════════════════════════════════════════════
object NotificationParser {

    // ── Amount patterns ──────────────────────────────────────────────

    private val AMOUNT_PATTERNS = listOf(
        // ₹ symbol (most common)
        Pattern.compile("""[₹]\s?([\d,]+\.?\d{0,2})"""),
        // "Rs" or "Rs." — case-insensitive
        Pattern.compile("""[Rr][Ss]\.?\s?([\d,]+\.?\d{0,2})"""),
        // "INR" — case-insensitive
        Pattern.compile("""[Ii][Nn][Rr]\s?([\d,]+\.?\d{0,2})"""),
        // "paid/sent ₹ X" — verb-first patterns
        Pattern.compile(
            """(?i)(?:paid|sent|debited|transferred)\s+(?:[₹]|[Rr][Ss]\.?|[Ii][Nn][Rr])?\s?([\d,]+\.?\d{0,2})"""
        ),
    )

    /** Extract the first valid monetary amount from [text]. */
    fun parseAmount(text: String): Double? {
        for (pattern in AMOUNT_PATTERNS) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val raw = matcher.group(1)?.replace(",", "") ?: continue
                val value = raw.toDoubleOrNull()
                if (value != null && value > 0.0) {
                    return value
                }
            }
        }
        return null
    }

    // ── Merchant patterns ────────────────────────────────────────────

    private data class MerchantPattern(
        val pattern: Pattern,
        val nameGroup: Int = 1,
    )

    private val MERCHANT_PATTERNS = listOf(
        // "₹250 paid to Swiggy"  /  "Paid ₹150 to Rahul"
        MerchantPattern(
            Pattern.compile(
                """(?i)(?:paid|sent|transferred)\s+(?:[₹Rr][Ss]?\.?|[Ii][Nn][Rr])?\s?[\d,]+\.?\d{0,2}\s+to\s+([A-Za-z][A-Za-z0-9 .&'-]{1,40})"""
            )
        ),
        // "Received ₹500 from Arjun"
        MerchantPattern(
            Pattern.compile(
                """(?i)received\s+(?:[₹Rr][Ss]?\.?|[Ii][Nn][Rr])?\s?[\d,]+\.?\d{0,2}\s+from\s+([A-Za-z][A-Za-z0-9 .&'-]{1,40})"""
            )
        ),
        // "to <name>" after amount — generic debit pattern
        MerchantPattern(
            Pattern.compile(
                """(?i)(?:[₹Rr][Ss]?\.?|[Ii][Nn][Rr])\s?[\d,]+\.?\d{0,2}\s+(?:paid\s+)?to\s+([A-Za-z][A-Za-z0-9 .&'-]{1,40})"""
            )
        ),
        // "from <name>" — generic credit pattern
        MerchantPattern(
            Pattern.compile(
                """(?i)(?:[₹Rr][Ss]?\.?|[Ii][Nn][Rr])\s?[\d,]+\.?\d{0,2}\s+from\s+([A-Za-z][A-Za-z0-9 .&'-]{1,40})"""
            )
        ),
        // "Payment to <name>" / "Money to <name>"
        MerchantPattern(
            Pattern.compile(
                """(?i)(?:payment|money)\s+to\s+([A-Za-z][A-Za-z0-9 .&'-]{1,40})"""
            )
        ),
        // "to <name>" — simple fallback
        MerchantPattern(
            Pattern.compile(
                """(?i)\bto\s+([A-Za-z][A-Za-z0-9 .&'-]{2,40})(?:\s+(?:on|via|using|from|\.|${'$'}))"""
            )
        ),
        // "from <name>" — simple credit fallback
        MerchantPattern(
            Pattern.compile(
                """(?i)\bfrom\s+([A-Za-z][A-Za-z0-9 .&'-]{2,40})(?:\s+(?:on|via|\.|${'$'}))"""
            )
        ),
    )

    // Trailing stopwords to strip from extracted names
    private val TRAILING_STOPWORDS = Regex(
        """(?i)\s+(?:via|on|at|in|using|through|successful|success|failed|complete)\s*${'$'}"""
    )

    /** Extract the payee/payer name from [text], or null if not found. */
    fun parseMerchant(text: String): String? {
        for (mp in MERCHANT_PATTERNS) {
            val matcher = mp.pattern.matcher(text)
            if (matcher.find()) {
                var name = matcher.group(mp.nameGroup)?.trim() ?: continue
                // Strip trailing stopwords
                name = name.replace(TRAILING_STOPWORDS, "").trim()
                if (name.length >= 2 && name.length <= 40 && !isJunkName(name)) {
                    return name
                }
            }
        }
        return null
    }

    private fun isJunkName(name: String): Boolean {
        val lower = name.lowercase()
        val junk = setOf(
            "upi", "imps", "neft", "rtgs", "bank", "payment",
            "transaction", "transfer", "account", "wallet", "via",
        )
        return junk.contains(lower)
    }

    // ── Type classification ───────────────────────────────────────────

    private val INCOME_KEYWORDS = listOf(
        "received", "credited", "money received", "you received",
        "got", "incoming", "added",
    )
    private val EXPENSE_KEYWORDS = listOf(
        "paid", "sent", "debited", "transferred", "payment successful",
        "payment of", "you paid", "money sent",
    )

    /**
     * Classify the transaction as "expense" (money out) or "income" (money in).
     * Defaults to "expense" since most payment app notifications are debits.
     */
    fun parseType(text: String): String {
        val lower = text.lowercase()
        for (kw in INCOME_KEYWORDS) if (lower.contains(kw)) return "income"
        for (kw in EXPENSE_KEYWORDS) if (lower.contains(kw)) return "expense"
        return "expense" // safe default
    }
}
