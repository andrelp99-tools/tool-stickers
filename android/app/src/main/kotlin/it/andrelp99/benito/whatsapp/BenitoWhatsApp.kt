package it.andrelp99.benito.whatsapp

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Process
import java.io.File

/**
 * BenitoSticker: invio dei pacchetti a WhatsApp (come nel progetto ufficiale
 * WhatsApp/stickers) e diagnosi quando WhatsApp li rifiuta.
 */
object BenitoWhatsApp {
    const val CONSUMER = "com.whatsapp"
    const val BUSINESS = "com.whatsapp.w4b"

    fun installed(context: Context, pkg: String): Boolean = try {
        if (Build.VERSION.SDK_INT >= 33) {
            context.packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION") context.packageManager.getPackageInfo(pkg, 0)
        }
        true
    } catch (_: Exception) {
        false
    }

    private fun version(context: Context, pkg: String): String = try {
        @Suppress("DEPRECATION")
        context.packageManager.getPackageInfo(pkg, 0).versionName ?: "?"
    } catch (_: Exception) {
        "non installato"
    }

    /** Apre la schermata "Aggiungi a WhatsApp". Restituisce false se WhatsApp non c'è. */
    fun startAdd(activity: Activity, identifier: String, name: String, requestCode: Int): Boolean {
        val consumer = installed(activity, CONSUMER)
        val business = installed(activity, BUSINESS)
        if (!consumer && !business) return false
        val intent = Intent("com.whatsapp.intent.action.ENABLE_STICKER_PACK").apply {
            putExtra("sticker_pack_id", identifier)
            putExtra("sticker_pack_authority", BenitoWaProvider.authority(activity))
            putExtra("sticker_pack_name", name)
        }
        if (consumer && business) {
            activity.startActivityForResult(Intent.createChooser(intent, "WhatsApp"), requestCode)
        } else {
            intent.setPackage(if (consumer) CONSUMER else BUSINESS)
            activity.startActivityForResult(intent, requestCode)
        }
        return true
    }

    /** Il pacchetto è già in WhatsApp? null = non si sa. */
    fun isAdded(context: Context, identifier: String): Boolean? {
        for (pkg in listOf(CONSUMER, BUSINESS)) {
            if (!installed(context, pkg)) continue
            val auth = if (pkg == CONSUMER) "com.whatsapp.provider.sticker_whitelist_check"
            else "com.whatsapp.w4b.provider.sticker_whitelist_check"
            try {
                val uri = Uri.Builder().scheme("content").authority(auth).appendPath("is_whitelisted")
                    .appendQueryParameter("authority", BenitoWaProvider.authority(context))
                    .appendQueryParameter("identifier", identifier).build()
                context.contentResolver.query(uri, null, null, null, null)?.use { c ->
                    if (c.moveToFirst()) {
                        if (c.getInt(c.getColumnIndexOrThrow("result")) == 1) return true
                    }
                }
            } catch (_: Exception) {
                return null
            }
        }
        return false
    }

    /**
     * Rifà le stesse letture che fa WhatsApp sul nostro provider e controlla i file.
     * Testo da copiare e mandare per capire cosa non va.
     */
    fun diagnose(context: Context, identifier: String, waError: String?): String {
        val sb = StringBuilder()
        sb.appendLine("BenitoSticker diagnosi")
        sb.appendLine("Errore WhatsApp: ${waError ?: "-"}")
        sb.appendLine("Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT}), ${Build.MANUFACTURER} ${Build.MODEL}")
        sb.appendLine("WhatsApp ${version(context, CONSUMER)}, Business ${version(context, BUSINESS)}")
        val auth = BenitoWaProvider.authority(context)
        sb.appendLine("Provider: $auth, pacchetto: $identifier")
        try {
            val meta = Uri.parse("content://$auth/${BenitoWaProvider.METADATA}/$identifier")
            var tray = "tray.png"
            var animated = false
            context.contentResolver.query(meta, null, null, null, null)?.use { c ->
                sb.appendLine("metadata: ${c.count} righe")
                if (c.moveToFirst()) {
                    tray = c.getString(c.getColumnIndexOrThrow("sticker_pack_icon"))
                    animated = c.getInt(c.getColumnIndexOrThrow("animated_sticker_pack")) == 1
                    sb.appendLine(
                        " nome='${c.getString(1)}' autore='${c.getString(2)}' versione=" +
                                c.getString(c.getColumnIndexOrThrow("image_data_version")) + " animato=$animated"
                    )
                }
            } ?: sb.appendLine("metadata: null")
            sb.appendLine("tray: " + describe(context, auth, identifier, tray))
            val files = mutableListOf<String>()
            context.contentResolver.query(
                Uri.parse("content://$auth/${BenitoWaProvider.STICKERS}/$identifier"), null, null, null, null
            )?.use { c ->
                while (c.moveToNext()) files.add(c.getString(0) + " [" + c.getString(1) + "]")
            }
            sb.appendLine("sticker: ${files.size}")
            for (f in files) {
                val name = f.substringBefore(" [")
                sb.appendLine(" $f " + describe(context, auth, identifier, name))
            }
        } catch (e: Exception) {
            sb.appendLine("ERRORE lettura provider: $e")
        }
        try {
            sb.appendLine("Già in WhatsApp: ${isAdded(context, identifier)}")
        } catch (_: Exception) {
        }
        sb.appendLine("--- log app ---")
        try {
            val p = Runtime.getRuntime().exec(arrayOf("logcat", "-d", "-t", "400", "--pid=${Process.myPid()}"))
            val lines = p.inputStream.bufferedReader().readLines().filter {
                it.contains("BenitoWa") || it.contains("Exception") || it.contains("sticker", ignoreCase = true) ||
                        it.contains(" E ")
            }
            lines.takeLast(40).forEach { sb.appendLine(it.take(300)) }
        } catch (e: Exception) {
            sb.appendLine("log non disponibile: $e")
        }
        return sb.toString()
    }

    private fun describe(context: Context, auth: String, identifier: String, file: String): String {
        return try {
            val uri = Uri.parse("content://$auth/${BenitoWaProvider.STICKERS_ASSET}/$identifier/$file")
            val bytes = context.contentResolver.openAssetFileDescriptor(uri, "r")?.use { afd ->
                afd.createInputStream().use { it.readBytes() }
            } ?: return "NON APRIBILE"
            val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
            val anim = isAnimatedWebp(bytes)
            "${bytes.size / 1024} kB ${opts.outWidth}x${opts.outHeight} ${opts.outMimeType ?: "?"}" +
                    (if (anim) " animato" else "")
        } catch (e: Exception) {
            "ERRORE $e"
        }
    }

    fun isAnimatedWebp(b: ByteArray): Boolean =
        b.size > 30 && String(b, 0, 4) == "RIFF" && String(b, 8, 4) == "WEBP" &&
                String(b, 12, 4) == "VP8X" && (b[20].toInt() and 0x02) != 0

    @Suppress("unused")
    fun waDir(context: Context, identifier: String) =
        File(File(BenitoWaProvider.packsRoot(context), identifier), "wa")
}
