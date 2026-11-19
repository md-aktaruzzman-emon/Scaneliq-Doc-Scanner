package com.scaneliq.scaneliq

import android.content.Context
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.FlutterInjector
import java.io.File
import java.io.FileOutputStream

/**
 * Offline native Bengali & Mixed Bengali-English OCR engine powered by Tesseract4Android
 * using Apache-2.0 tessdata_fast models (`ben.traineddata` and `eng.traineddata`).
 */
class TesseractOcrEngine(private val context: Context) {
    private val tessRootDir: File by lazy {
        File(context.filesDir, "tesseract_data")
    }
    private val tessDataDir: File by lazy {
        File(tessRootDir, "tessdata")
    }

    fun ensureModelsReady(): Map<String, Boolean> {
        if (!tessDataDir.exists()) {
            tessDataDir.mkdirs()
        }
        val benReady = copyAssetIfNeeded("assets/tessdata/ben.traineddata", "ben.traineddata")
        val engReady = copyAssetIfNeeded("assets/tessdata/eng.traineddata", "eng.traineddata")
        return mapOf(
            "ben" to benReady,
            "eng" to engReady,
        )
    }

    private fun copyAssetIfNeeded(assetRelativePath: String, targetName: String): Boolean {
        val targetFile = File(tessDataDir, targetName)
        if (targetFile.exists() && targetFile.length() > 100_000L) {
            return true
        }
        return try {
            val loader = FlutterInjector.instance().flutterLoader()
            val lookupKey = loader.getLookupKeyForAsset(assetRelativePath)
            context.assets.open(lookupKey).use { input ->
                val tmp = File(tessDataDir, "$targetName.tmp")
                FileOutputStream(tmp).use { output ->
                    input.copyTo(output)
                }
                if (targetFile.exists()) {
                    targetFile.delete()
                }
                tmp.renameTo(targetFile)
            }
            targetFile.exists() && targetFile.length() > 0L
        } catch (_: Exception) {
            false
        }
    }

    fun recognizeImage(imagePath: String, lang: String): Map<String, Any> {
        val imageFile = File(imagePath)
        require(imageFile.exists()) { "Image file not found: $imagePath" }

        val readiness = ensureModelsReady()
        val effectiveLang = when (lang) {
            "ben+eng" -> if (readiness["ben"] == true && readiness["eng"] == true) "ben+eng" else if (readiness["ben"] == true) "ben" else "eng"
            "ben" -> if (readiness["ben"] == true) "ben" else throw IllegalStateException("Bengali tessdata model unavailable")
            else -> if (readiness["eng"] == true) "eng" else throw IllegalStateException("English tessdata model unavailable")
        }

        val tess = TessBaseAPI()
        return try {
            val initialized = tess.init(tessRootDir.absolutePath, effectiveLang, TessBaseAPI.OEM_LSTM_ONLY)
            if (!initialized) {
                throw IllegalStateException("TessBaseAPI initialization failed for language: $effectiveLang")
            }
            tess.pageSegMode = TessBaseAPI.PageSegMode.PSM_AUTO
            tess.setImage(imageFile)

            val fullText = tess.utF8Text ?: ""
            val lineBoxes = mutableListOf<Map<String, Any>>()
            val iterator = tess.resultIterator
            if (iterator != null) {
                iterator.begin()
                do {
                    val lineText = iterator.getUTF8Text(TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE)
                    val rect = iterator.getBoundingRect(TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE)
                    if (!lineText.isNullOrBlank() && rect != null) {
                        lineBoxes.add(
                            mapOf(
                                "text" to lineText.trim(),
                                "left" to rect.left.toDouble(),
                                "top" to rect.top.toDouble(),
                                "width" to rect.width().toDouble(),
                                "height" to rect.height().toDouble(),
                            ),
                        )
                    }
                } while (iterator.next(TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE))
                iterator.delete()
            }

            mapOf(
                "fullText" to fullText.trim(),
                "boxes" to lineBoxes,
                "engine" to "tesseract4android:$effectiveLang",
            )
        } finally {
            tess.recycle()
        }
    }
}
