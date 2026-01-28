package com.example.uebungsleiter_helper

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "uebungsleiter_helper/battery_optimization").setMethodCallHandler { call, result ->
			if (call.method == "openBatteryOptimization") {
				try {
					val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
						Intent("android.settings.APP_BATTERY_SETTINGS").apply {
							data = Uri.parse("package:$packageName")
							putExtra("android.provider.extra.APP_PACKAGE", packageName)
						}
					} else {
						Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
							data = Uri.parse("package:$packageName")
						}
					}
					intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
					try {
						startActivity(intent)
					} catch (e: Exception) {
						val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
							data = Uri.parse("package:$packageName")
							addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
						}
						startActivity(fallback)
					}
					result.success(true)
				} catch (e: Exception) {
					result.error("ERROR", "Could not open battery optimization settings", null)
				}
			} else if (call.method == "isIgnoringBatteryOptimizations") {
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
					try {
						val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
						result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
					} catch (e: Exception) {
						result.error("ERROR", "Could not read battery optimization status", null)
					}
				} else {
					result.success(null)
				}
			} else {
				result.notImplemented()
			}
		}
	}
}
