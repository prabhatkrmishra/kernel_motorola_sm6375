package com.rifsxd.ksunext.ui.webui

import android.content.Context
import android.content.res.Configuration
import android.os.Build

import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.ui.graphics.toArgb

/**
 * @author rifsxd
 * @date 2025/6/2.
 */
object MonetColorsProvider {
    fun getColorsCss(context: Context): String {

        // Detect dark mode
        val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

        val colorScheme = if (isDark) {
            dynamicDarkColorScheme(context)
        } else {
            dynamicLightColorScheme(context)
        }

        val monetColors = mapOf(
            "primary" to colorScheme.primary.toArgb().toHex(),
            "onPrimary" to colorScheme.onPrimary.toArgb().toHex(),
            "background" to colorScheme.background.toArgb().toHex(),
            "onSurface" to colorScheme.onSurface.toArgb().toHex(),
            "onSurfaceVariant" to colorScheme.onSurfaceVariant.toArgb().toHex(),
            "tonalSurface" to colorScheme.surface.toArgb().toHex(),
            "surfaceBright" to colorScheme.surfaceVariant.toArgb().toHex(),
            "outlineVariant" to colorScheme.outlineVariant.toArgb().toHex(),
            "error" to colorScheme.error.toArgb().toHex()
        )

        return monetColors.toCssVars()
    }

    private fun Map<String, String>.toCssVars(): String {
        return buildString {
            append(":root {\n")
            for ((k, v) in this@toCssVars) {
                append("  --$k: $v;\n")
            }
            append("}\n")
        }
    }

    private fun Int.toHex(): String {
        return String.format("#%06X", 0xFFFFFF and this)
    }
}