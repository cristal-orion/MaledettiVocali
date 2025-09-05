package com.example.maledetti_vocali

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import com.github.axet.androidlibrary.sound.OpusDecoder

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.maledettivocali/converter"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "convertOpusToWav") {
                val path = call.argument<String>("path")
                if (path != null) {
                    try {
                        val outputFile = convertToWav(path)
                        result.success(outputFile)
                    } catch (e: Exception) {
                        result.error("CONVERSION_ERROR", "Failed to convert file: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Path cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun convertToWav(inputPath: String): String {
        val inputFile = File(inputPath)
        val tempDir = cacheDir
        val outputFile = File(tempDir, "${System.currentTimeMillis()}.wav")
        
        val decoder = OpusDecoder()

        val fileInputStream = FileInputStream(inputFile)
        val fileOutputStream = FileOutputStream(outputFile)

        // Write WAV header
        writeWavHeader(fileOutputStream, 48000, 1, 0) // Placeholder for size

        var totalBytes = 0
        val buffer = ByteArray(960 * 2) // Frame size * 2 bytes per sample
        val pcm = ShortArray(960)

        decoder.create(48000, 1)

        while (fileInputStream.available() > 0) {
            val bytesRead = fileInputStream.read(buffer)
            if (bytesRead > 0) {
                val decodedSamples = decoder.decode(buffer, pcm)
                val byteBuffer = ByteBuffer.allocate(decodedSamples * 2).order(ByteOrder.LITTLE_ENDIAN)
                for (i in 0 until decodedSamples) {
                    byteBuffer.putShort(pcm[i])
                }
                fileOutputStream.write(byteBuffer.array(), 0, decodedSamples * 2)
                totalBytes += decodedSamples * 2
            }
        }

        fileInputStream.close()
        fileOutputStream.close()
        
        // Update WAV header with correct size
        updateWavHeader(outputFile, totalBytes)

        decoder.close()
        
        return outputFile.path
    }
    
    private fun writeWavHeader(out: FileOutputStream, sampleRate: Int, channels: Int, totalAudioLen: Int) {
        val totalDataLen = totalAudioLen + 36
        val byteRate = (sampleRate * channels * 16) / 8
        
        out.write(byteArrayOf(
            'R'.toByte(), 'I'.toByte(), 'F'.toByte(), 'F'.toByte(),
            (totalDataLen and 0xff).toByte(), (totalDataLen shr 8 and 0xff).toByte(), (totalDataLen shr 16 and 0xff).toByte(), (totalDataLen shr 24 and 0xff).toByte(),
            'W'.toByte(), 'A'.toByte(), 'V'.toByte(), 'E'.toByte(),
            'f'.toByte(), 'm'.toByte(), 't'.toByte(), ' '.toByte(),
            16, 0, 0, 0,
            1, 0,
            channels.toByte(), 0,
            (sampleRate and 0xff).toByte(), (sampleRate shr 8 and 0xff).toByte(), (sampleRate shr 16 and 0xff).toByte(), (sampleRate shr 24 and 0xff).toByte(),
            (byteRate and 0xff).toByte(), (byteRate shr 8 and 0xff).toByte(), (byteRate shr 16 and 0xff).toByte(), (byteRate shr 24 and 0xff).toByte(),
            (channels * 16 / 8).toByte(), 0,
            16, 0,
            'd'.toByte(), 'a'.toByte(), 't'.toByte(), 'a'.toByte(),
            (totalAudioLen and 0xff).toByte(), (totalAudioLen shr 8 and 0xff).toByte(), (totalAudioLen shr 16 and 0xff).toByte(), (totalAudioLen shr 24 and 0xff).toByte()
        ))
    }

    private fun updateWavHeader(file: File, totalAudioLen: Int) {
        val totalDataLen = totalAudioLen + 36
        val data = file.readBytes()
        data[4] = (totalDataLen and 0xff).toByte()
        data[5] = (totalDataLen shr 8 and 0xff).toByte()
        data[6] = (totalDataLen shr 16 and 0xff).toByte()
        data[7] = (totalDataLen shr 24 and 0xff).toByte()
        data[40] = (totalAudioLen and 0xff).toByte()
        data[41] = (totalAudioLen shr 8 and 0xff).toByte()
        data[42] = (totalAudioLen shr 16 and 0xff).toByte()
        data[43] = (totalAudioLen shr 24 and 0xff).toByte()
        FileOutputStream(file).write(data)
    }
}
