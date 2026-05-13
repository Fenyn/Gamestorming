package com.lifemagic.wear

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.health.services.client.HealthServices
import androidx.health.services.client.MeasureCallback
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataPointContainer
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DeltaDataType
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

class HRStreamingService : LifecycleService(), SensorEventListener {

    companion object {
        private const val TAG = "HRStreaming"
        private const val CHANNEL_ID = "hr_streaming"
        private const val NOTIFICATION_ID = 1
        private const val HR_PATH = "/life-magic/hr"
        private const val DISCONNECT_PATH = "/life-magic/disconnect"
        private const val BPM_CHANGE_THRESHOLD = 3
        private const val KEEPALIVE_MS = 50_000L

        var currentBpm: Int = 0
            private set
        var isStreaming: Boolean = false
            private set
    }

    private var phoneNodeId: String? = null
    private var dailySteps: Int = 0
    private var stepsAtBoot: Int = -1
    private var sensorManager: SensorManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastSentBpm: Int = 0
    private var lastSendTime: Long = 0L

    private val measureClient by lazy {
        HealthServices.getClient(this).measureClient
    }

    private val hrCallback = object : MeasureCallback {
        override fun onAvailabilityChanged(
            dataType: DeltaDataType<*, *>,
            availability: Availability
        ) {
            Log.d(TAG, "HR availability: $availability")
        }

        override fun onDataReceived(data: DataPointContainer) {
            val samples = data.getData(DataType.HEART_RATE_BPM)
            val bpm = samples.lastOrNull()?.value?.toInt() ?: return
            currentBpm = bpm
            val bpmDelta = kotlin.math.abs(bpm - lastSentBpm)
            val timeSinceSend = System.currentTimeMillis() - lastSendTime
            if (bpmDelta >= BPM_CHANGE_THRESHOLD || lastSentBpm == 0 || timeSinceSend >= KEEPALIVE_MS) {
                lastSentBpm = bpm
                lastSendTime = System.currentTimeMillis()
                updateNotification(bpm)
                lifecycleScope.launch { sendToPhone(bpm) }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startStepCounter()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        startForeground(NOTIFICATION_ID, buildNotification(0))
        val pm = getSystemService(PowerManager::class.java)
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "LifeMagic::HRStream")
        wakeLock?.acquire()
        lifecycleScope.launch {
            findPhoneNode()
            startHRMeasurement()
        }
        isStreaming = true
        return START_STICKY
    }

    override fun onDestroy() {
        isStreaming = false
        currentBpm = 0
        lifecycleScope.launch {
            sendDisconnect()
            try {
                measureClient.unregisterMeasureCallbackAsync(DataType.HEART_RATE_BPM, hrCallback).await()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to unregister HR callback: ${e.message}")
            }
        }
        wakeLock?.release()
        wakeLock = null
        sensorManager?.unregisterListener(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent): IBinder? {
        super.onBind(intent)
        return null
    }

    private suspend fun findPhoneNode() {
        try {
            val nodes = Wearable.getNodeClient(this).connectedNodes.await()
            phoneNodeId = nodes.firstOrNull()?.id
            if (phoneNodeId != null) {
                Log.i(TAG, "Found phone node: $phoneNodeId")
            } else {
                Log.w(TAG, "No connected nodes found")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to find phone node: ${e.message}")
        }
    }

    private suspend fun startHRMeasurement() {
        try {
            val capabilities = measureClient.getCapabilitiesAsync().await()
            val supportsHR = DataType.HEART_RATE_BPM in capabilities.supportedDataTypesMeasure
            if (!supportsHR) {
                Log.e(TAG, "Heart rate not supported on this device")
                return
            }
            measureClient.registerMeasureCallback(DataType.HEART_RATE_BPM, hrCallback)
            Log.i(TAG, "HR measurement started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start HR measurement: ${e.message}")
        }
    }

    private fun startStepCounter() {
        sensorManager = getSystemService(SensorManager::class.java)
        val stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (stepSensor != null) {
            sensorManager?.registerListener(this, stepSensor, SensorManager.SENSOR_DELAY_UI)
        } else {
            Log.w(TAG, "Step counter sensor not available")
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_STEP_COUNTER) {
            val totalSteps = event.values[0].toInt()
            if (stepsAtBoot < 0) {
                stepsAtBoot = totalSteps
            }
            dailySteps = totalSteps - stepsAtBoot
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private suspend fun sendDisconnect() {
        val nodeId = phoneNodeId ?: return
        try {
            Wearable.getMessageClient(this@HRStreamingService)
                .sendMessage(nodeId, DISCONNECT_PATH, ByteArray(0))
                .await()
        } catch (_: Exception) {}
    }

    private suspend fun sendToPhone(bpm: Int) {
        val nodeId = phoneNodeId
        if (nodeId == null) {
            findPhoneNode()
            return
        }
        val payload = """{"bpm":$bpm,"steps":$dailySteps,"ts":${System.currentTimeMillis()}}"""
        try {
            Wearable.getMessageClient(this)
                .sendMessage(nodeId, HR_PATH, payload.toByteArray())
                .await()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to send HR to phone: ${e.message}")
            phoneNodeId = null
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.notification_channel),
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(bpm: Int): Notification {
        val text = if (bpm > 0) getString(R.string.bpm_format, bpm) else getString(R.string.streaming_active)
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_heart)
            .setContentTitle(getString(R.string.notification_title))
            .setContentText(text)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(bpm: Int) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(bpm))
    }
}
