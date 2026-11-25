package com.deskpanel.deskpanel

import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "deskpanel/sound").setMethodCallHandler { call, result ->
            when (call.method) {
                "notify" -> {
                    try {
                        playNotification()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("sound", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** The user's default notification sound on the notification stream (honours its
     *  volume, silent mode and Do Not Disturb). */
    private fun playNotification() {
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION) ?: return
        ringtone?.stop()
        ringtone = RingtoneManager.getRingtone(applicationContext, uri)?.apply {
            audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            play()
        }
    }
}
