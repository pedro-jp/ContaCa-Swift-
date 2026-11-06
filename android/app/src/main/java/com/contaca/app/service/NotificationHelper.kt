package com.contaca.app.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.contaca.app.MainActivity

object NotificationHelper {

    const val CHANNEL_WATER = "channel_water_reminders"
    const val CHANNEL_WORKOUT = "channel_workout_active"
    const val CHANNEL_SUMMARY = "channel_daily_summary"

    const val NOTIFICATION_ID_WORKOUT = 1001
    const val NOTIFICATION_ID_WATER = 1002

    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val waterChannel = NotificationChannel(
                CHANNEL_WATER,
                "Lembretes de Hidratação",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Lembretes diários para beber água e atingir sua meta"
            }

            val workoutChannel = NotificationChannel(
                CHANNEL_WORKOUT,
                "Treino em Andamento",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Status do treino ativo e queima calórica em tempo real"
            }

            val summaryChannel = NotificationChannel(
                CHANNEL_SUMMARY,
                "Resumo Diário",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Balanço nutricional e calórico do dia"
            }

            manager.createNotificationChannel(waterChannel)
            manager.createNotificationChannel(workoutChannel)
            manager.createNotificationChannel(summaryChannel)
        }
    }

    fun showWaterReminder(context: Context, targetMl: Int, currentMl: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val remaining = maxOf(0, targetMl - currentMl)
        val notif = NotificationCompat.Builder(context, CHANNEL_WATER)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("💧 Hora de se hidratar!")
            .setContentText("Você já bebeu $currentMl ml hoje. Faltam $remaining ml para sua meta.")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(NOTIFICATION_ID_WATER, notif)
    }

    fun showWorkoutOngoingNotification(context: Context, title: String, elapsedSeconds: Int, calories: Double) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val mins = elapsedSeconds / 60
        val secs = elapsedSeconds % 60
        val timeStr = String.format("%02d:%02d", mins, secs)

        val notif = NotificationCompat.Builder(context, CHANNEL_WORKOUT)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("🔥 Treino Ativo: $title")
            .setContentText("Tempo: $timeStr | ${calories.toInt()} kcal queimadas")
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(NOTIFICATION_ID_WORKOUT, notif)
    }

    fun cancelWorkoutNotification(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID_WORKOUT)
    }
}
