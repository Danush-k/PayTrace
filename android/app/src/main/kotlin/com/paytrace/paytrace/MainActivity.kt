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

    /**
     * Read recent SMS from inbox via ContentResolver.
     * NO FILTERING on the native side — sends ALL SMS received after
     * [sinceTimestamp] to Dart. The Dart-side matchesPending() handles
     * precise amount matching. This ensures we never miss a bank SMS
     * due to unknown sender IDs or unexpected message formats.
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

            Log.d("PayTrace", "readRecentSms: permission OK, querying since $sinceTimestamp")

            val uri = Telephony.Sms.Inbox.CONTENT_URI
            val projection = arrayOf(
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
            )
            val selection = "${Telephony.Sms.DATE} > ?"
            val selectionArgs = arrayOf(sinceTimestamp.toString())
            val sortOrder = "${Telephony.Sms.DATE} DESC"

            val cursor: Cursor? = contentResolver.query(
                uri, projection, selection, selectionArgs, sortOrder
            )

            val smsList = mutableListOf<Map<String, String>>()

            cursor?.use {
                val addressIdx = it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val bodyIdx = it.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val dateIdx = it.getColumnIndexOrThrow(Telephony.Sms.DATE)

                var count = 0
                while (it.moveToNext() && count < 50) {
                    val sender = it.getString(addressIdx) ?: ""
                    val body = it.getString(bodyIdx) ?: ""
                    val timestamp = it.getLong(dateIdx)

                    Log.d("PayTrace", "SMS[$count] from=$sender body=${body.take(80)}")
                    smsList.add(mapOf(
                        "sender" to sender,
                        "body" to body,
                        "timestamp" to timestamp.toString()
                    ))
                    count++
                }
            }

            Log.d("PayTrace", "readRecentSms: returning ${smsList.size} SMS to Dart")
            result.success(smsList)

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
