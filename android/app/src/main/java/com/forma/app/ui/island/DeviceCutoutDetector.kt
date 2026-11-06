package com.forma.app.ui.island

import android.app.Activity
import android.os.Build
import android.view.DisplayCutout
import android.view.WindowInsets

enum class CutoutType(val displayName: String, val description: String) {
    CENTER_HOLE("Furo Central (Punch Hole)", "Samsung S20-S24, Pixel 6-8, Xiaomi, Motorola Edge"),
    LEFT_HOLE("Furo no Canto Esquerdo", "Galaxy S10, OnePlus 8/9, Realme"),
    PILL_SHAPED("Pílula Central Larga", "Estilo iPhone Dynamic Island"),
    WATERDROP_NOTCH("Gota D'água (Waterdrop)", "Redmi Note, Galaxy A, Moto G"),
    FLOATING_TOP_BAR("Barra Flutuante Superior", "Universal para qualquer celular ou tablet")
}

data class IslandPreset(
    val type: CutoutType,
    val name: String,
    val xOffsetDp: Int = 0,
    val yOffsetDp: Int = 10,
    val compactWidthDp: Int = 140,
    val compactHeightDp: Int = 36,
    val cornerRadiusDp: Int = 20,
    val expandedWidthDp: Int = 340,
    val expandedHeightDp: Int = 160
) {
    companion object {
        val ALL_PRESETS = listOf(
            IslandPreset(
                type = CutoutType.CENTER_HOLE,
                name = "Samsung Galaxy / Pixel (Furo Central)",
                xOffsetDp = 0,
                yOffsetDp = 38,
                compactWidthDp = 150,
                compactHeightDp = 38,
                cornerRadiusDp = 20,
                expandedWidthDp = 340,
                expandedHeightDp = 165
            ),
            IslandPreset(
                type = CutoutType.LEFT_HOLE,
                name = "OnePlus / S10 (Furo no Canto Esquerdo)",
                xOffsetDp = -90,
                yOffsetDp = 38,
                compactWidthDp = 145,
                compactHeightDp = 38,
                cornerRadiusDp = 20,
                expandedWidthDp = 330,
                expandedHeightDp = 165
            ),
            IslandPreset(
                type = CutoutType.PILL_SHAPED,
                name = "Pílula Dinâmica Larga (Estilo iPhone Pro)",
                xOffsetDp = 0,
                yOffsetDp = 38,
                compactWidthDp = 180,
                compactHeightDp = 40,
                cornerRadiusDp = 22,
                expandedWidthDp = 350,
                expandedHeightDp = 175
            ),
            IslandPreset(
                type = CutoutType.WATERDROP_NOTCH,
                name = "Notch em Gota (Redmi / Moto G / Galaxy A)",
                xOffsetDp = 0,
                yOffsetDp = 42,
                compactWidthDp = 155,
                compactHeightDp = 40,
                cornerRadiusDp = 20,
                expandedWidthDp = 330,
                expandedHeightDp = 165
            ),
            IslandPreset(
                type = CutoutType.FLOATING_TOP_BAR,
                name = "Barra Flutuante Superior (Universal)",
                xOffsetDp = 0,
                yOffsetDp = 44,
                compactWidthDp = 165,
                compactHeightDp = 40,
                cornerRadiusDp = 22,
                expandedWidthDp = 340,
                expandedHeightDp = 165
            )
        )

        fun getDefaultPreset(): IslandPreset = ALL_PRESETS.first()
    }
}

object DeviceCutoutDetector {

    fun detectPreset(activity: Activity? = null): IslandPreset {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val model = Build.MODEL.lowercase()

        // 1. Detecção via WindowInsets.displayCutout (Android 9+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && activity != null) {
            val windowInsets = activity.window.decorView.rootWindowInsets
            val cutout: DisplayCutout? = windowInsets?.displayCutout
            if (cutout != null && cutout.boundingRects.isNotEmpty()) {
                val rect = cutout.boundingRects.first()
                val screenWidth = activity.resources.displayMetrics.widthPixels
                val centerX = screenWidth / 2
                val cutoutCenter = (rect.left + rect.right) / 2

                return when {
                    // Canto esquerdo
                    cutoutCenter < (centerX - 100) -> {
                        IslandPreset.ALL_PRESETS.first { it.type == CutoutType.LEFT_HOLE }
                    }
                    // Pílula larga no topo
                    rect.width() > 180 -> {
                        IslandPreset.ALL_PRESETS.first { it.type == CutoutType.PILL_SHAPED }
                    }
                    // Furo central
                    else -> {
                        IslandPreset.ALL_PRESETS.first { it.type == CutoutType.CENTER_HOLE }
                    }
                }
            }
        }

        // 2. Detecção baseada em Marca e Modelo
        return when {
            model.contains("s10") || model.contains("oneplus") || model.contains("nord") -> {
                IslandPreset.ALL_PRESETS.first { it.type == CutoutType.LEFT_HOLE }
            }
            model.contains("redmi") || model.contains("moto g") || model.contains("galaxy a") -> {
                IslandPreset.ALL_PRESETS.first { it.type == CutoutType.WATERDROP_NOTCH }
            }
            manufacturer.contains("samsung") || manufacturer.contains("google") || manufacturer.contains("xiaomi") -> {
                IslandPreset.ALL_PRESETS.first { it.type == CutoutType.CENTER_HOLE }
            }
            else -> {
                IslandPreset.ALL_PRESETS.first { it.type == CutoutType.CENTER_HOLE }
            }
        }
    }

    fun getDeviceSummary(): String {
        return "${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL} (Android ${Build.VERSION.RELEASE})"
    }
}
