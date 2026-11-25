package com.deskpanel.deskpanel

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "deskpanel/open").setMethodCallHandler { call, result ->
            val url = call.argument<String>("url")
            if (call.method != "url" || url == null || !(url.startsWith("https://") || url.startsWith("http://"))) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            result.success(openUrl(url))
        }
    }

    /** Opens [url] in the app that handles it: YouTube links in the YouTube app when it's
     *  installed (so it plays at full quality), anything else in the browser. */
    private fun openUrl(url: String): Boolean {
        val uri = Uri.parse(url)
        val host = uri.host ?: ""
        val view = Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (host == "youtu.be" || host.endsWith("youtube.com")) {
            try {
                startActivity(Intent(view).setPackage("com.google.android.youtube"))
                return true
            } catch (_: ActivityNotFoundException) {
                // no YouTube app: fall through to the browser
            }
        }
        return try {
            startActivity(view)
            true
        } catch (_: ActivityNotFoundException) {
            false
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
