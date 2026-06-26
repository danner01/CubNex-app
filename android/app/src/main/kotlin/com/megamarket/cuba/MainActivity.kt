package com.cubnex.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File

class MainActivity : FlutterActivity() {
    private val ocrChannel = "cubnex/ocr"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ocrChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "recognizeText" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("PATH_REQUIRED", "La ruta de imagen es requerida.", null)
                        return@setMethodCallHandler
                    }
                    recognizeText(path, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun recognizeText(path: String, result: MethodChannel.Result) {
        try {
            val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            recognizer.process(image)
                .addOnSuccessListener { visionText ->
                    val lines = visionText.textBlocks
                        .flatMap { it.lines }
                        .map { it.text }
                        .filter { it.isNotBlank() }
                    result.success(
                        mapOf(
                            "text" to visionText.text,
                            "lines" to lines,
                        )
                    )
                }
                .addOnFailureListener { error ->
                    result.error("OCR_FAILED", error.message ?: "No se pudo reconocer texto.", null)
                }
        } catch (error: Exception) {
            result.error("OCR_FAILED", error.message ?: "No se pudo leer la imagen.", null)
        }
    }
}
