package com.paytrace.paytrace

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.paytrace.paytrace/upi"
    private val EVENT_CHANNEL = "com.paytrace.paytrace/notifications"
    private val SMS_PERMISSION_CODE = 2001
    private val MAX_SMS_SCAN = 1200
    private val HISTORICAL_WINDOW_MS = 90L * 24 * 60 * 60 * 1000

    private var notificationEventSink: EventChannel.EventSink? = null
    private var pendingSmsPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method channel for UPI operations
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getUpiApps" -> getUpiApps(result)
                    "launchApp" -> launchApp(call, result)
                    "launchUpiPayIntent" -> launchUpiPayIntent(call, result)
                    "isAppInstalled" -> isAppInstalled(call, result)
                    "isNotificationAccessEnabled" -> {
                        result.success(PaymentNotificationListener.isEnabled(this))
                    }
                    "openNotificationSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    }
                    "rebindNotificationListener" -> {
                        try {
                            val componentName = android.content.ComponentName(
                                this, PaymentNotificationListener::class.java
                            )
                            packageManager.setComponentEnabledSetting(
                                componentName,
                                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                android.content.pm.PackageManager.DONT_KILL_APP
                            )
                            packageManager.setComponentEnabledSetting(
                                componentName,
                                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                                android.content.pm.PackageManager.DONT_KILL_APP
                            )
                            android.util.Log.d("PayTrace", "NLS rebind triggered")
                            result.success(true)
                        } catch (e: Exception) {
                            android.util.Log.e("PayTrace", "NLS rebind failed: ${e.message}")
                            result.error("REBIND_ERROR", e.message, null)
                        }
                    }
                    "testNotification" -> {
                        val testData = mapOf(
                            "package" to "com.paytrace.test",
                            "title" to "Test Payment",
                            "text" to "You paid ₹1.00 to Test User",
                            "timestamp" to System.currentTimeMillis().toString()
                        )
                        val sink = notificationEventSink
                        if (sink != null) {
                            runOnUiThread { sink.success(testData) }
                            result.success("sent")
                        } else {
                            result.success("no_sink")
                        }
                    }
                    "openAppSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    }
                    "hasSmsPermission" -> {
                        val granted = android.Manifest.permission.READ_SMS.let {
                            androidx.core.content.ContextCompat.checkSelfPermission(this, it)
                        } == android.content.pm.PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    }
                    "requestSmsPermission" -> {
                        pendingSmsPermissionResult = result
                        androidx.core.app.ActivityCompat.requestPermissions(
                            this,
                            arrayOf(
                                android.Manifest.permission.READ_SMS,
                            ),
                            SMS_PERMISSION_CODE
                        )
                    }
                    "readRecentSms" -> {
                        val sinceTimestamp = call.argument<Long>("since") ?: 0L
                        readRecentSms(sinceTimestamp, result)
                    }
                    else -> result.notImplemented()
                }
            }

        // Event channel for streaming payment notifications
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    notificationEventSink = events
                    PaymentNotificationListener.onNotificationReceived = { data ->
                        runOnUiThread {
                            notificationEventSink?.success(data)
                        }
                    }
                    android.util.Log.d("PayTrace", "Notification event channel listening")

                    val pending = PaymentNotificationListener.drainPending()
                    if (pending.isNotEmpty()) {
                        android.util.Log.d("PayTrace", "Draining ${pending.size} buffered notifications")
                        for (data in pending) {
                            runOnUiThread {
                                notificationEventSink?.success(data)
                            }
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    notificationEventSink = null
                    PaymentNotificationListener.onNotificationReceived = null
                    android.util.Log.d("PayTrace", "Notification event channel cancelled")
                }
            })

    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED
            pendingSmsPermissionResult?.success(granted)
            pendingSmsPermissionResult = null
        }
    }

    private fun getUpiApps(result: MethodChannel.Result) {
        try {
            val upiIntent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("upi://pay")
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PackageManager.MATCH_ALL
            } else {
                PackageManager.MATCH_DEFAULT_ONLY
            }
            val resolvedApps = packageManager.queryIntentActivities(upiIntent, flags)
            val apps = resolvedApps.map { resolveInfo ->
                mapOf(
                    "packageName" to resolveInfo.activityInfo.packageName,
                    "appName" to resolveInfo.loadLabel(packageManager).toString()
                )
            }
            result.success(apps)
        } catch (e: Exception) {
            result.error("UPI_APPS_ERROR", e.message, null)
        }
    }

    private fun launchApp(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("package")
        if (packageName == null) {
            result.error("INVALID_ARGS", "Package name required", null)
            return
        }
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                startActivity(intent)
                result.success(true)
            } else {
                result.error("APP_NOT_FOUND", "$packageName not installed", null)
            }
        } catch (e: Exception) {
            result.error("LAUNCH_ERROR", e.message, null)
        }
    }

    private fun launchUpiPayIntent(call: MethodCall, result: MethodChannel.Result) {
        val pa = call.argument<String>("pa")?.trim()
        val pn = call.argument<String>("pn")?.trim()
        val am = call.argument<String>("am")?.trim()
        val tn = call.argument<String>("tn")?.trim()
        val tr = call.argument<String>("tr")?.trim()
        val cu = call.argument<String>("cu")?.trim().orEmpty().ifEmpty { "INR" }
        val packageName = call.argument<String>("package")?.trim()

        if (pa.isNullOrEmpty() || pn.isNullOrEmpty() || am.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "pa, pn, and am are required", null)
            return
        }

        try {
            val uriBuilder = Uri.Builder()
                .scheme("upi")
                .authority("pay")
                .appendQueryParameter("pa", pa)
                .appendQueryParameter("pn", pn)
                .appendQueryParameter("am", am)
                .appendQueryParameter("cu", cu)

            if (!tn.isNullOrEmpty()) {
                uriBuilder.appendQueryParameter("tn", tn)
            }
            if (!tr.isNullOrEmpty()) {
                uriBuilder.appendQueryParameter("tr", tr)
            }

            val uri = uriBuilder.build()
            val intent = Intent(Intent.ACTION_VIEW, uri)

            if (!packageName.isNullOrEmpty()) {
                intent.setPackage(packageName)
            }

            val canHandle = intent.resolveActivity(packageManager) != null
            if (!canHandle) {
                if (!packageName.isNullOrEmpty()) {
                    val fallbackIntent = Intent(Intent.ACTION_VIEW, uri)
                    if (fallbackIntent.resolveActivity(packageManager) != null) {
                        startActivity(Intent.createChooser(fallbackIntent, "Pay with"))
                        result.success(true)
                        return
                    }
                }
                result.error("UPI_INTENT_UNAVAILABLE", "No app can handle UPI payment intent", null)
                return
            }

            if (packageName.isNullOrEmpty()) {
                startActivity(Intent.createChooser(intent, "Pay with"))
            } else {
                startActivity(intent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("UPI_INTENT_ERROR", e.message, null)
        }
    }

    /**
     * Read historical SMS from both inbox + sent via ContentResolver.
     *
     * Native side performs only basic extraction (address/body/date/type)
     * and time-window bounds. Semantic filtering/classification happens in Dart.
     */
    private fun readRecentSms(sinceTimestamp: Long, result: MethodChannel.Result) {
        try {
            // Check READ_SMS permission
            val hasPermission = androidx.core.content.ContextCompat.checkSelfPermission(
                this, android.Manifest.permission.READ_SMS
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED

            if (!hasPermission) {
                Log.e("PayTrace", "readRecentSms: READ_SMS PERMISSION DENIED")
                result.success(emptyList<Map<String, String>>())
                return
            }

            val minTimestamp = maxOf(
                sinceTimestamp,
                System.currentTimeMillis() - HISTORICAL_WINDOW_MS,
            )
            Log.d("PayTrace", "readRecentSms: permission OK, querying since $minTimestamp")

            val projection = arrayOf(
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.TYPE,
            )
            val selection = "${Telephony.Sms.DATE} > ?"
            val selectionArgs = arrayOf(minTimestamp.toString())
            val sortOrder = "${Telephony.Sms.DATE} DESC"

            val smsList = mutableListOf<Map<String, String>>()

            fun collectFrom(uri: Uri, fallbackType: String) {
                val cursor: Cursor? = contentResolver.query(
                    uri,
                    projection,
                    selection,
                    selectionArgs,
                    sortOrder,
                )

                cursor?.use {
                    val addressIdx = it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                    val bodyIdx = it.getColumnIndexOrThrow(Telephony.Sms.BODY)
                    val dateIdx = it.getColumnIndexOrThrow(Telephony.Sms.DATE)
                    val typeIdx = it.getColumnIndexOrThrow(Telephony.Sms.TYPE)

                    while (it.moveToNext()) {
                        if (smsList.size >= MAX_SMS_SCAN) break

                        val sender = it.getString(addressIdx) ?: ""
                        val body = it.getString(bodyIdx) ?: ""
                        val timestamp = it.getLong(dateIdx)
                        val rawType = it.getInt(typeIdx)
                        val smsType = when (rawType) {
                            Telephony.Sms.MESSAGE_TYPE_SENT -> "sent"
                            Telephony.Sms.MESSAGE_TYPE_INBOX -> "inbox"
                            else -> fallbackType
                        }

                        smsList.add(
                            mapOf(
                                "sender" to sender,
                                "body" to body,
                                "timestamp" to timestamp.toString(),
                                "type" to smsType,
                            )
                        )
                    }
                }
            }

            collectFrom(Telephony.Sms.Inbox.CONTENT_URI, "inbox")
            if (smsList.size < MAX_SMS_SCAN) {
                collectFrom(Telephony.Sms.Sent.CONTENT_URI, "sent")
            }

            val sorted = smsList
                .sortedByDescending { it["timestamp"]?.toLongOrNull() ?: 0L }
                .take(MAX_SMS_SCAN)

            Log.d("PayTrace", "readRecentSms: returning ${sorted.size} SMS to Dart")
            result.success(sorted)

        } catch (e: Exception) {
            Log.e("PayTrace", "readRecentSms error: ${e.message}")
            result.error("SMS_READ_ERROR", e.message, null)
        }
    }

    private fun isAppInstalled(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("package")
        if (packageName == null) {
            result.error("INVALID_ARGS", "Package name required", null)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            result.success(true)
        } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
            result.success(false)
        } catch (e: Exception) {
            result.success(false)
        }
    }
}
