package com.lifemagic.wear

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.view.Gravity
import android.view.ViewGroup.LayoutParams
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private lateinit var statusText: TextView
    private lateinit var bpmText: TextView
    private lateinit var toggleButton: Button

    private val sensorPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            updateUI()
        } else {
            statusText.text = getString(R.string.permission_required)
        }
    }

    private val notificationPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { _ ->
        // Notification permission is optional — proceed regardless
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(24, 24, 24, 24)
        }

        statusText = TextView(this).apply {
            text = getString(R.string.streaming_inactive)
            textSize = 14f
            gravity = Gravity.CENTER
        }

        bpmText = TextView(this).apply {
            text = ""
            textSize = 32f
            gravity = Gravity.CENTER
        }

        toggleButton = Button(this).apply {
            text = getString(R.string.start)
            setOnClickListener { toggleStreaming() }
        }

        layout.addView(bpmText, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        layout.addView(statusText, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        layout.addView(toggleButton, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))

        setContentView(layout)

        requestPermissions()
        startBpmUpdateLoop()
    }

    private fun requestPermissions() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BODY_SENSORS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            sensorPermission.launch(Manifest.permission.BODY_SENSORS)
        }

        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    private fun toggleStreaming() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BODY_SENSORS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            sensorPermission.launch(Manifest.permission.BODY_SENSORS)
            return
        }

        if (HRStreamingService.isStreaming) {
            stopService(Intent(this, HRStreamingService::class.java))
        } else {
            val intent = Intent(this, HRStreamingService::class.java)
            ContextCompat.startForegroundService(this, intent)
        }
        updateUI()
    }

    private fun updateUI() {
        val streaming = HRStreamingService.isStreaming
        toggleButton.text = getString(if (streaming) R.string.stop else R.string.start)
        statusText.text = getString(if (streaming) R.string.streaming_active else R.string.streaming_inactive)
    }

    private fun startBpmUpdateLoop() {
        lifecycleScope.launch {
            while (true) {
                val bpm = HRStreamingService.currentBpm
                bpmText.text = if (bpm > 0) getString(R.string.bpm_format, bpm) else ""
                updateUI()
                delay(1000)
            }
        }
    }
}
