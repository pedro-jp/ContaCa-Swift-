package com.contaca.app.ui.island

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.core.app.NotificationCompat
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.contaca.app.ContaCaApplication
import com.contaca.app.MainActivity
import com.contaca.app.R
import com.contaca.app.ui.theme.ContaCaTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

class DynamicIslandOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var overlayComposeView: ComposeView? = null
    private var overlayLifecycleOwner: OverlayLifecycleOwner? = null
    private var windowLayoutParams: WindowManager.LayoutParams? = null

    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        _isServiceRunning.value = true
        startAsForeground()

        if (!canDrawOverlays(this)) {
            stopSelf()
            return
        }

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        setupOverlayWindow()
    }

    private fun startAsForeground() {
        val channelId = "dynamic_island_overlay_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Ilha Dinâmica do Sistema",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Mantém a Ilha Dinâmica ativa sobre outros aplicativos"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }

        val launchIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Forma Ilha Dinâmica")
            .setContentText("Ilha ativa sobre outros aplicativos")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(1001, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1001, notification)
        }
    }

    private fun setupOverlayWindow() {
        val wm = windowManager ?: return
        val islandState = DynamicIslandState.getInstance(this)
        val density = resources.displayMetrics.density

        val initialPreset = islandState.preset.value
        val initialX = (initialPreset.xOffsetDp + islandState.customXOffset.value) * density
        val initialY = (initialPreset.yOffsetDp + islandState.customYOffset.value) * density

        val params = WindowManager.LayoutParams(
            (initialPreset.compactWidthDp * density).toInt(),
            (initialPreset.compactHeightDp * density).toInt(),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = initialX.toInt()
            y = initialY.toInt()
        }
        windowLayoutParams = params

        val lifecycleOwner = OverlayLifecycleOwner().apply { start() }
        overlayLifecycleOwner = lifecycleOwner

        val composeView = ComposeView(this).apply {
            setViewTreeLifecycleOwner(lifecycleOwner)
            setViewTreeSavedStateRegistryOwner(lifecycleOwner)
            setViewTreeViewModelStoreOwner(lifecycleOwner)

            setContent {
                ContaCaTheme {
                    DynamicIslandView(
                        modifier = Modifier.fillMaxSize(),
                        isInsideOverlayService = true,
                        onQuickAddWater = {
                            ContaCaApplication.instance.repository.addWater(250)
                        }
                    )
                }
            }
        }
        overlayComposeView = composeView

        try {
            wm.addView(composeView, params)
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
            return
        }

        // Observa alterações de dimensões, offset e expansão para atualizar LayoutParams
        serviceScope.launch {
            combine(
                islandState.isExpanded,
                islandState.preset,
                islandState.customXOffset,
                islandState.customYOffset,
                islandState.isEnabled
            ) { isExpanded, preset, customX, customY, isEnabled ->
                LayoutState(isExpanded, preset, customX, customY, isEnabled)
            }.collectLatest { state ->
                val p = windowLayoutParams ?: return@collectLatest
                val view = overlayComposeView ?: return@collectLatest

                if (!state.isEnabled) {
                    view.visibility = android.view.View.GONE
                    return@collectLatest
                } else {
                    view.visibility = android.view.View.VISIBLE
                }

                if (state.isExpanded) {
                    p.width = (state.preset.expandedWidthDp * density).toInt()
                    p.height = (state.preset.expandedHeightDp * density).toInt()
                    p.x = 0
                    p.y = ((state.preset.yOffsetDp + state.customY) * density).toInt()
                } else {
                    p.width = (state.preset.compactWidthDp * density).toInt()
                    p.height = (state.preset.compactHeightDp * density).toInt()
                    p.x = ((state.preset.xOffsetDp + state.customX) * density).toInt()
                    p.y = ((state.preset.yOffsetDp + state.customY) * density).toInt()
                }

                try {
                    wm.updateViewLayout(view, p)
                } catch (_: Exception) {}
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        _isServiceRunning.value = false
        serviceScope.cancel()

        overlayComposeView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        overlayLifecycleOwner?.stop()
        overlayComposeView = null
        overlayLifecycleOwner = null
    }

    private data class LayoutState(
        val isExpanded: Boolean,
        val preset: IslandPreset,
        val customX: Int,
        val customY: Int,
        val isEnabled: Boolean
    )

    companion object {
        private val _isServiceRunning = MutableStateFlow(false)
        val isServiceRunning: StateFlow<Boolean> = _isServiceRunning.asStateFlow()

        fun canDrawOverlays(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(context)
            } else true
        }

        fun start(context: Context) {
            if (!canDrawOverlays(context)) return
            val intent = Intent(context, DynamicIslandOverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, DynamicIslandOverlayService::class.java)
            context.stopService(intent)
        }
    }
}
