package it.andrelp99.benito.whatsapp

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.UriMatcher
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * BenitoSticker: fornisce i pacchetti a WhatsApp, con lo stesso formato del progetto
 * ufficiale WhatsApp/stickers (Android, versione novembre 2025).
 *
 * I dati li prepara l'app Flutter quando si tocca "Aggiungi a WhatsApp":
 *  - <dati app>/app_flutter/packs/whatsapp.json  (elenco pacchetti inviati)
 *  - <dati app>/app_flutter/packs/<id>/wa/       (tray.png + 1.webp, 2.webp, …)
 */
class BenitoWaProvider : ContentProvider() {

    companion object {
        private const val TAG = "BenitoWa"
        const val METADATA = "metadata"
        const val STICKERS = "stickers"
        const val STICKERS_ASSET = "stickers_asset"
        private const val CODE_METADATA = 1
        private const val CODE_METADATA_SINGLE = 2
        private const val CODE_STICKERS = 3
        private const val CODE_ASSET = 4

        fun authority(context: Context) = context.packageName + ".benito.stickers"

        fun packsRoot(context: Context) = File(File(context.filesDir.parentFile, "app_flutter"), "packs")

        fun configFile(context: Context) = File(packsRoot(context), "whatsapp.json")

        /** Legge whatsapp.json: identificatore → oggetto JSON del pacchetto. */
        fun readPacks(context: Context): List<JSONObject> {
            val f = configFile(context)
            if (!f.exists()) return emptyList()
            return try {
                val arr = JSONObject(f.readText()).optJSONArray("packs") ?: return emptyList()
                (0 until arr.length()).mapNotNull { arr.optJSONObject(it) }
            } catch (e: Exception) {
                Log.e(TAG, "whatsapp.json non leggibile", e)
                emptyList()
            }
        }
    }

    private val matcher = UriMatcher(UriMatcher.NO_MATCH)

    override fun onCreate(): Boolean {
        val auth = authority(context!!)
        matcher.addURI(auth, METADATA, CODE_METADATA)
        matcher.addURI(auth, "$METADATA/*", CODE_METADATA_SINGLE)
        matcher.addURI(auth, "$STICKERS/*", CODE_STICKERS)
        matcher.addURI(auth, "$STICKERS_ASSET/*/*", CODE_ASSET)
        return true
    }

    override fun query(
        uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?
    ): Cursor {
        Log.i(TAG, "query $uri")
        val ctx = context!!
        return when (matcher.match(uri)) {
            CODE_METADATA -> packCursor(uri, readPacks(ctx))
            CODE_METADATA_SINGLE -> packCursor(uri, readPacks(ctx).filter { it.optString("identifier") == uri.lastPathSegment })
            CODE_STICKERS -> stickersCursor(uri, uri.lastPathSegment ?: "")
            else -> throw IllegalArgumentException("URI sconosciuto: $uri")
        }
    }

    private fun packCursor(uri: Uri, packs: List<JSONObject>): Cursor {
        val cursor = MatrixCursor(
            arrayOf(
                "sticker_pack_identifier",
                "sticker_pack_name",
                "sticker_pack_publisher",
                "sticker_pack_icon",
                "android_play_store_link",
                "ios_app_download_link",
                "sticker_pack_publisher_email",
                "sticker_pack_publisher_website",
                "sticker_pack_privacy_policy_website",
                "sticker_pack_license_agreement_website",
                "image_data_version",
                "whatsapp_will_not_cache_stickers",
                "animated_sticker_pack",
            )
        )
        for (p in packs) {
            cursor.newRow()
                .add(p.optString("identifier"))
                .add(p.optString("name"))
                .add(p.optString("publisher"))
                .add(p.optString("tray", "tray.png"))
                .add("")
                .add("")
                .add("")
                .add("")
                .add("")
                .add("")
                .add(p.optString("image_data_version", "1"))
                .add(0)
                .add(if (p.optBoolean("animated")) 1 else 0)
        }
        cursor.setNotificationUri(context!!.contentResolver, uri)
        return cursor
    }

    private fun stickersCursor(uri: Uri, identifier: String): Cursor {
        val cursor = MatrixCursor(arrayOf("sticker_file_name", "sticker_emoji", "sticker_accessibility_text"))
        readPacks(context!!).firstOrNull { it.optString("identifier") == identifier }?.let { p ->
            val stickers = p.optJSONArray("stickers")
            if (stickers != null) {
                for (i in 0 until stickers.length()) {
                    val s = stickers.getJSONObject(i)
                    val emojis = s.optJSONArray("emojis")
                    val list = if (emojis == null) listOf("❤") else (0 until emojis.length()).map { emojis.getString(it) }
                    cursor.addRow(arrayOf<Any?>(s.optString("file"), list.joinToString(","), s.optString("a11y", "")))
                }
            }
        }
        cursor.setNotificationUri(context!!.contentResolver, uri)
        return cursor
    }

    override fun openAssetFile(uri: Uri, mode: String): AssetFileDescriptor? {
        Log.i(TAG, "openAssetFile $uri")
        if (matcher.match(uri) != CODE_ASSET) return null
        val segments = uri.pathSegments
        if (segments.size != 3) return null
        val identifier = segments[1]
        val fileName = segments[2]
        // Solo file elencati nel pacchetto (niente percorsi arbitrari)
        val pack = readPacks(context!!).firstOrNull { it.optString("identifier") == identifier } ?: return null
        val allowed = mutableSetOf(pack.optString("tray", "tray.png"))
        pack.optJSONArray("stickers")?.let { arr ->
            for (i in 0 until arr.length()) allowed.add(arr.getJSONObject(i).optString("file"))
        }
        if (fileName !in allowed || fileName.contains('/') || fileName.contains("..")) {
            Log.w(TAG, "file non nel pacchetto: $fileName")
            return null
        }
        val file = File(File(File(packsRoot(context!!), identifier), "wa"), fileName)
        if (!file.exists()) {
            Log.e(TAG, "file mancante: $file")
            return null
        }
        return AssetFileDescriptor(
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY), 0, file.length()
        )
    }

    override fun getType(uri: Uri): String {
        val auth = authority(context!!)
        return when (matcher.match(uri)) {
            CODE_METADATA -> "vnd.android.cursor.dir/vnd.$auth.$METADATA"
            CODE_METADATA_SINGLE -> "vnd.android.cursor.item/vnd.$auth.$METADATA"
            CODE_STICKERS -> "vnd.android.cursor.dir/vnd.$auth.$STICKERS"
            CODE_ASSET -> if (uri.lastPathSegment?.endsWith(".png") == true) "image/png" else "image/webp"
            else -> throw IllegalArgumentException("URI sconosciuto: $uri")
        }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException()
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException()

    override fun update(
        uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?
    ): Int = throw UnsupportedOperationException()
}
