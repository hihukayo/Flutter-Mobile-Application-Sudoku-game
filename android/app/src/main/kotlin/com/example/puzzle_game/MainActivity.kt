package com.example.puzzle_game

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.puzzle_game/click"
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, _ ->
            when (call.method) {
                "vibrate" -> vibrate()
                "tone_click" -> playClickTone()
                "tone_success" -> playSuccessTone()
            }
        }
    }

    private fun vibrate() {
        val vibrator: Vibrator =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(80, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(80)
        }
    }

    private fun playTone(frequency: Double, durationMs: Int, endFreq: Double? = null) {
        Thread {
            try {
                val sampleRate = 44100
                val numSamples = sampleRate * durationMs / 1000
                val buffer = ShortArray(numSamples)

                for (i in 0 until numSamples) {
                    val t = i.toDouble() / sampleRate
                    val progress = t / (durationMs / 1000.0)
                    val freq = if (endFreq != null) frequency + (endFreq - frequency) * progress else frequency
                    val envelope = (1.0 - progress * 1.3).coerceAtLeast(0.0)
                    val sample = (envelope * sin(2.0 * PI * freq * t) * 30000).toInt()
                    buffer[i] = sample.toShort()
                }

                val track = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    AudioTrack.Builder()
                        .setAudioAttributes(AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_GAME)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build())
                        .setAudioFormat(AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build())
                        .setBufferSizeInBytes(numSamples * 2)
                        .setTransferMode(AudioTrack.MODE_STATIC)
                        .build()
                } else {
                    @Suppress("DEPRECATION")
                    AudioTrack(AudioManager.STREAM_MUSIC, sampleRate,
                        AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
                        numSamples * 2, AudioTrack.MODE_STATIC)
                }

                track.write(buffer, 0, numSamples)
                track.play()
                mainHandler.postDelayed({
                    try { track.stop(); track.release() } catch (_: Exception) {}
                }, (durationMs + 50).toLong())
            } catch (_: Exception) {}
        }.start()
    }

    private fun playClickTone() = playTone(1200.0, 80)

    private fun playSuccessTone() = playTone(600.0, 160, endFreq = 1200.0)
}
