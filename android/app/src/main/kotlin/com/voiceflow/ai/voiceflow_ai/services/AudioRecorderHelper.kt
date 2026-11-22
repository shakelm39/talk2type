package com.voiceflow.ai.voiceflow_ai.services

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.util.Log
import java.io.File

class AudioRecorderHelper(private val context: Context) {

    companion object {
        private const val TAG = "AudioRecorderHelper"
    }

    private var mediaRecorder: MediaRecorder? = null
    private var currentOutputFile: File? = null
    var isRecording: Boolean = false
        private set

    fun getMaxAmplitude(): Int {
        return try {
            mediaRecorder?.maxAmplitude ?: 0
        } catch (_: Exception) {
            0
        }
    }

    fun startRecording(): String? {
        if (isRecording) {
            Log.w(TAG, "Already recording. Stop previous session first.")
            return currentOutputFile?.absolutePath
        }

        try {
            val audioDir = File(context.cacheDir, "voice_records")
            if (!audioDir.exists()) {
                audioDir.mkdirs()
            }

            val outputFile = File(audioDir, "vf_voice_${System.currentTimeMillis()}.m4a")
            currentOutputFile = outputFile

            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            recorder.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(128000)
                setOutputFile(outputFile.absolutePath)
                prepare()
                start()
            }

            mediaRecorder = recorder
            isRecording = true
            Log.i(TAG, "Recording started at: ${outputFile.absolutePath}")
            return outputFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start audio recording: ${e.message}", e)
            cleanUp()
            return null
        }
    }

    fun stopRecording(): String? {
        if (!isRecording) {
            Log.w(TAG, "Not currently recording.")
            return null
        }

        val filePath = currentOutputFile?.absolutePath
        try {
            mediaRecorder?.apply {
                try {
                    stop()
                } catch (e: RuntimeException) {
                    Log.w(TAG, "MediaRecorder stop failed (possibly too short): ${e.message}")
                }
                reset()
                release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error while stopping MediaRecorder: ${e.message}", e)
        } finally {
            mediaRecorder = null
            isRecording = false
        }

        if (filePath != null) {
            val file = File(filePath)
            if (file.exists() && file.length() > 0) {
                Log.i(TAG, "Recording saved successfully. Size: ${file.length()} bytes, Path: $filePath")
                return filePath
            } else {
                Log.w(TAG, "Recorded file is empty or does not exist.")
            }
        }
        return null
    }

    fun cancelRecording() {
        if (isRecording) {
            try {
                mediaRecorder?.apply {
                    try {
                        stop()
                    } catch (_: Exception) {}
                    reset()
                    release()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error cancelling recorder: ${e.message}")
            } finally {
                mediaRecorder = null
                isRecording = false
            }
        }

        currentOutputFile?.let {
            if (it.exists()) {
                it.delete()
            }
        }
        currentOutputFile = null
    }

    private fun cleanUp() {
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {}
        mediaRecorder = null
        isRecording = false
        currentOutputFile = null
    }
}
