package com.paytrace.paytrace

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.telephony.SmsMessage
import android.util.Log

/**
 * Receives incoming SMS and forwards bank debit/UPI messages
 * to Flutter via a static callback.
 *
 * Bank SMS patterns we look for:
 * - "Rs.500.00 debited from A/c XX1234"
 * - "INR 500 debited"
 * - "UPI/P2P/123456789/abc@ybl"
 * - "sent Rs 500"
 * - "UPI Ref No 123456789"
 * - "Transaction of Rs.500"
 */
class SmsBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PayTrace:SMS"

        /**
         * Static callback set by MainActivity when Flutter is active.
         * Receives: Map<String, String> with keys: sender, body, timestamp
         */
        var onSmsReceived: ((Map<String, String>) -> Unit)? = null

        /**
         * Buffer for SMS received while Flutter isn't listening.
         */
        private val pendingSms = mutableListOf<Map<String, String>>()

        fun drainPending(): List<Map<String, String>> {
            val copy = pendingSms.toList()
            pendingSms.clear()
            return copy
        }

        // Bank sender IDs — short codes and sender patterns
        // Indian banks use sender IDs like VM-SBIPSG, AD-HDFCBK, etc.
        private val BANK_SENDER_PATTERNS = listOf(
            // SBI
            "SBI", "SBIPSG", "SBMSBI", "SBIINB", "SBIATM",
            // HDFC
            "HDFC", "HDFCBK",
            // ICICI
            "ICICI", "ICICIB",
            // Axis
            "AXISBK", "AXIS",
            // Kotak
            "KOTAK", "KOTAKB",
            // PNB
            "PNBSMS",
            // BOB
            "BOBTXN", "BOBSMS",
            // Union Bank
            "UBOI",
            // Canara
            "CANBNK",
            // IndusInd
            "INDBNK",
            // IDFC
            "IDFCFB",
            // Yes Bank
            "YESBK",
            // Federal
            "FEDBNK",
            // RBL
            "RBLBNK",
            // NPCI / UPI
            "UPIBLK", "NPCI",
            // Paytm Payments Bank
            "PYTM", "PAYTMB",
            // Airtel Payments Bank
            "AIRTEL",
            // Jupiter / Fi
            "JUPBNK", "FIBNK",
            // Slice
            "SLICE",
            // Generic
            "DEBITS", "ALERTS",
        )

        /**
         * Check if the sender looks like a bank/financial institution.
         */
        fun isBankSender(sender: String): Boolean {
            val upper = sender.uppercase()
            // Short codes like VM-SBIINB, AD-HDFCBK, BZ-ICICIB etc.
            for (pattern in BANK_SENDER_PATTERNS) {
                if (upper.contains(pattern)) return true
            }
            return false
        }

        /**
         * Check if the SMS body looks like a UPI debit notification.
         */
        fun isUpiDebitSms(body: String): Boolean {
            val lower = body.lowercase()
            // Must contain some amount indicator
            val hasAmount = lower.contains("rs") ||
                    lower.contains("rs.") ||
                    lower.contains("inr") ||
                    lower.contains("₹")

            // Must contain debit/payment indicator
            val hasDebit = lower.contains("debit") ||
                    lower.contains("sent") ||
                    lower.contains("paid") ||
                    lower.contains("transferred") ||
                    lower.contains("withdrawn") ||
                    lower.contains("transaction of") ||
                    lower.contains("purchase")

            // UPI-specific markers
            val hasUpi = lower.contains("upi") ||
                    lower.contains("imps") ||
                    lower.contains("neft")

            // It's a UPI debit SMS if it has amount AND (debit indicator OR UPI marker)
            return hasAmount && (hasDebit || hasUpi)
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != "android.provider.Telephony.SMS_RECEIVED") return

        val bundle: Bundle = intent.extras ?: return
        val pdus = bundle.get("pdus") as? Array<*> ?: return
        val format = bundle.getString("format", "3gpp")

        // Reconstruct messages (multi-part SMS)
        val messages = pdus.mapNotNull { pdu ->
            if (pdu is ByteArray) {
                SmsMessage.createFromPdu(pdu, format)
            } else null
        }

        // Group by sender to handle multi-part messages
        val grouped = messages.groupBy { it.originatingAddress ?: "" }

        for ((sender, parts) in grouped) {
            val fullBody = parts.joinToString("") { it.messageBody ?: "" }
            val timestamp = parts.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()

            if (fullBody.isBlank()) continue

            Log.d(TAG, "SMS from $sender: ${fullBody.take(100)}...")

            // Forward if sender looks like a bank OR body looks like a payment SMS
            // Cast a WIDE net — Dart-side matching handles precision
            val isBank = isBankSender(sender)
            val isDebit = isUpiDebitSms(fullBody)
            val hasAmount = fullBody.contains("₹") ||
                    fullBody.lowercase().contains("rs.") ||
                    fullBody.lowercase().contains("rs ") ||
                    fullBody.lowercase().contains("debited")

            if (!isBank && !isDebit && !hasAmount) {
                Log.d(TAG, "→ Not a financial SMS, skipping")
                continue
            }

            Log.d(TAG, "★ UPI debit SMS detected from $sender!")

            val data = mapOf(
                "sender" to sender,
                "body" to fullBody,
                "timestamp" to timestamp.toString()
            )

            val callback = onSmsReceived
            if (callback != null) {
                Log.d(TAG, "→ Sending to Flutter via callback")
                callback.invoke(data)
            } else {
                Log.d(TAG, "→ Flutter not listening, buffering SMS")
                synchronized(pendingSms) {
                    pendingSms.add(data)
                    while (pendingSms.size > 5) {
                        pendingSms.removeAt(0)
                    }
                }
            }
        }
    }
}
