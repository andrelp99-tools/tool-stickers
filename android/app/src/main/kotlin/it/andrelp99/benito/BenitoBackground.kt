package it.andrelp99.benito

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.os.Build
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * BenitoSticker: rimozione sfondo sul telefono con ML Kit (Google Play services,
 * modello scaricato una volta, poi tutto offline). Restituisce un PNG trasparente.
 */
object BenitoBackground {
    private const val MAX_SIDE = 2048

    suspend fun removeBackground(context: Context, input: File): String {
        val bitmap = decode(input)
        val options = SubjectSegmenterOptions.Builder().enableForegroundBitmap().build()
        val segmenter = SubjectSegmentation.getClient(options)
        try {
            val foreground: Bitmap = suspendCancellableCoroutine { cont ->
                segmenter.process(InputImage.fromBitmap(bitmap, 0))
                    .addOnSuccessListener { result ->
                        val fg = result.foregroundBitmap
                        if (fg == null) cont.resumeWithException(IllegalStateException("Nessun soggetto trovato"))
                        else cont.resume(fg)
                    }
                    .addOnFailureListener { cont.resumeWithException(it) }
            }
            val out = File(context.cacheDir, "benito_nobg_${System.currentTimeMillis()}.png")
            out.outputStream().use { foreground.compress(Bitmap.CompressFormat.PNG, 100, it) }
            return out.absolutePath
        } finally {
            segmenter.close()
        }
    }

    /** Decodifica rispettando l'orientamento della foto e ridimensionando se enorme. */
    private fun decode(file: File): Bitmap {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            return ImageDecoder.decodeBitmap(ImageDecoder.createSource(file)) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                val w = info.size.width
                val h = info.size.height
                val max = maxOf(w, h)
                if (max > MAX_SIDE) {
                    val s = MAX_SIDE.toFloat() / max
                    decoder.setTargetSize((w * s).toInt().coerceAtLeast(1), (h * s).toInt().coerceAtLeast(1))
                }
            }
        }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_SIDE) sample *= 2
        return BitmapFactory.decodeFile(file.absolutePath, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: throw IllegalStateException("Immagine non leggibile")
    }
}
