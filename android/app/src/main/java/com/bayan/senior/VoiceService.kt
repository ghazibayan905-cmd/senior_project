package com.bayan.senior

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import android.Manifest
import android.content.pm.PackageManager

class VoiceService : Service() {

    companion object {
        fun start(context: Context) {
            val intent = Intent(context, VoiceService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, VoiceService::class.java)
            context.stopService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()

        // 1) فحص إذن المايك
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) {
            stopSelf()
            return
        }

        // 2) إنشاء قناة الإشعار
        createNotificationChannel()

        // 3) تشغيل الخدمة في المقدمة
        val notification = NotificationCompat.Builder(this, "voice_channel")
            .setContentTitle("Voice Assistant")
            .setContentText("Listening for wake word…")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()

        startForeground(1, notification)

        // 4) تشغيل مستمع wake word
        startWakeWordListener()
    }

    private fun startWakeWordListener() {
        Thread {
            while (true) {
                Thread.sleep(1500)

                // هنا لازم يكون عندك كود wake word الحقيقي
                // أنا رح أعمل مثال بسيط:
                val detected = FakeWakeWordEngine.listen()

                if (detected) {
                    openApp()
                }
            }
        }.start()
    }

    private fun openApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "voice_channel",
                "Voice Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}

// محرك wake word وهمي — استبدليه بمحركك الحقيقي
object FakeWakeWordEngine {
    fun listen(): Boolean {
        return false // غيريها لما تضيفي wake word الحقيقي
    }
}
