package com.scaneliq.scaneliq

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val TESSERACT_CHANNEL = "com.scaneliq.scaneliq/tesseract"
        private const val SECURITY_CHANNEL = "com.scaneliq.scaneliq/security"
    }

    private val ocrExecutor = Executors.newSingleThreadExecutor()
    private lateinit var tesseractEngine: TesseractOcrEngine
    private var isFlagSecureEnabled: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        tesseractEngine = TesseractOcrEngine(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TESSERACT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkModelsReady" -> {
                    ocrExecutor.execute {
                        try {
                            val readiness = tesseractEngine.ensureModelsReady()
                            runOnUiThread { result.success(readiness) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("TESS_MODEL_ERR", e.message, null)
                            }
                        }
                    }
                }
                "extractText" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val lang = call.argument<String>("lang") ?: "ben"
                    if (imagePath.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Missing imagePath", null)
                        return@setMethodCallHandler
                    }
                    ocrExecutor.execute {
                        try {
                            val data = tesseractEngine.recognizeImage(imagePath, lang)
                            runOnUiThread { result.success(data) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("TESS_OCR_ERR", e.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURITY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setFlagSecure" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        isFlagSecureEnabled = enabled
                        result.success(isFlagSecureEnabled)
                    }
                }
                "getFlagSecure" -> result.success(isFlagSecureEnabled)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        ocrExecutor.shutdown()
        super.onDestroy()
    }
}
