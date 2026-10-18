package it.andrelp99.benito

import java.io.File
import java.io.FileInputStream

/** BenitoSticker: binding JNI di benito_webp.cpp (stessa libreria "stickers"). */
object BenitoWebP {
    init {
        System.loadLibrary("stickers")
    }

    @JvmStatic external fun nativeEncodeStatic(
        rgba: ByteArray, width: Int, height: Int, quality: Float, lossless: Boolean
    ): ByteArray?

    @JvmStatic external fun nativeAnimStart(width: Int, height: Int, quality: Float, lossless: Boolean): Long
    @JvmStatic external fun nativeAnimAdd(handle: Long, rgba: ByteArray, durationMs: Int): Boolean
    @JvmStatic external fun nativeAnimFinish(handle: Long): ByteArray?

    /**
     * Legge da [framesFile] i fotogrammi RGBA (width x height, uno dopo l'altro)
     * e li codifica in un WebP animato.
     */
    fun encodeAnimatedFromFile(
        framesFile: File, durations: List<Int>, width: Int, height: Int, quality: Float
    ): ByteArray? {
        val handle = nativeAnimStart(width, height, quality, false)
        if (handle == 0L) return null
        val frame = ByteArray(width * height * 4)
        try {
            FileInputStream(framesFile).buffered().use { input ->
                for (d in durations) {
                    var read = 0
                    while (read < frame.size) {
                        val n = input.read(frame, read, frame.size - read)
                        if (n < 0) break
                        read += n
                    }
                    if (read < frame.size || !nativeAnimAdd(handle, frame, d)) break
                }
            }
        } catch (e: Exception) {
            nativeAnimFinish(handle)
            throw e
        }
        return nativeAnimFinish(handle)
    }
}
