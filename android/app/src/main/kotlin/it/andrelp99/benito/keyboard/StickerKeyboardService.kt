package it.andrelp99.benito.keyboard

import android.content.ClipDescription
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.inputmethodservice.InputMethodService
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.BaseAdapter
import android.widget.FrameLayout
import android.widget.GridView
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.FileProvider
import androidx.core.view.inputmethod.EditorInfoCompat
import androidx.core.view.inputmethod.InputConnectionCompat
import androidx.core.view.inputmethod.InputContentInfoCompat
import org.json.JSONArray
import java.io.File
import java.util.concurrent.Executors

/**
 * BenitoSticker: tastiera sticker. Mostra i pacchetti dell'app e, al tocco,
 * inserisce lo sticker nell'app in uso (commitContent). Se l'app non accetta
 * immagini dalla tastiera, apre "Condividi" verso quella stessa app.
 */
class StickerKeyboardService : InputMethodService() {

    private data class Pack(val title: String, val tray: String?, val stickers: List<String>, val animated: Boolean)

    private val io = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())
    private val thumbs = object : LruCache<String, Bitmap>(16 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

    private var packs: List<Pack> = emptyList()
    private var current = 0 // 0 = recenti
    private lateinit var grid: GridView
    private lateinit var tabs: LinearLayout
    private lateinit var empty: TextView

    private val dark get() =
        (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
    private val bg get() = if (dark) Color.rgb(28, 28, 30) else Color.rgb(240, 240, 243)
    private val fg get() = if (dark) Color.WHITE else Color.BLACK
    private val accent = Color.rgb(255, 64, 129)

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    override fun onCreateInputView(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bg)
            layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(300))
        }

        // Barra pacchetti
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val switchKb = TextView(this).apply {
            text = "⌨"
            textSize = 22f
            setTextColor(fg)
            gravity = Gravity.CENTER
            setOnClickListener { switchBack() }
            contentDescription = "Tastiera precedente"
        }
        bar.addView(switchKb, LinearLayout.LayoutParams(dp(52), dp(48)))
        tabs = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        val scroll = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            addView(tabs)
        }
        bar.addView(scroll, LinearLayout.LayoutParams(0, dp(48), 1f))
        root.addView(bar)

        val content = FrameLayout(this)
        grid = GridView(this).apply {
            numColumns = GridView.AUTO_FIT
            columnWidth = dp(76)
            stretchMode = GridView.STRETCH_COLUMN_WIDTH
            verticalSpacing = dp(6)
            horizontalSpacing = dp(6)
            setPadding(dp(6), dp(4), dp(6), dp(6))
            clipToPadding = false
        }
        empty = TextView(this).apply {
            setTextColor(fg)
            alpha = .7f
            gravity = Gravity.CENTER
            setPadding(dp(24), 0, dp(24), 0)
            visibility = View.GONE
        }
        content.addView(grid, FrameLayout.LayoutParams(-1, -1))
        content.addView(empty, FrameLayout.LayoutParams(-1, -1))
        root.addView(content, LinearLayout.LayoutParams(-1, 0, 1f))
        return root
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        packs = loadPacks()
        if (current > packs.size) current = 0
        if (current == 0 && recents().isEmpty() && packs.isNotEmpty()) current = 1
        buildTabs()
        showCurrent()
    }

    // --- Dati ---

    private fun loadPacks(): List<Pack> = try {
        // Stesso file dell'app Flutter: <dati app>/app_flutter/packs/packs.json
        val file = File(File(filesDir.parentFile, "app_flutter"), "packs/packs.json")
        val arr = JSONArray(file.readText())
        (0 until arr.length()).map { i ->
            val p = arr.getJSONObject(i)
            val st = p.getJSONArray("stickers")
            Pack(
                p.optString("title"),
                p.optString("trayIcon").takeIf { it.isNotEmpty() && it != "null" },
                (0 until st.length()).map { st.getJSONObject(it).getString("source") }.filter { File(it).exists() },
                p.optBoolean("animated"),
            )
        }.filter { it.stickers.isNotEmpty() }
    } catch (_: Exception) {
        emptyList()
    }

    private fun prefs() = getSharedPreferences("benito_keyboard", MODE_PRIVATE)

    private fun recents(): List<String> =
        (prefs().getString("recent", "") ?: "").split('\n').filter { it.isNotEmpty() && File(it).exists() }

    private fun addRecent(path: String) {
        val list = (listOf(path) + recents().filter { it != path }).take(24)
        prefs().edit().putString("recent", list.joinToString("\n")).apply()
    }

    // --- Interfaccia ---

    private fun buildTabs() {
        tabs.removeAllViews()
        addTab(0, null, "🕘")
        packs.forEachIndexed { i, p -> addTab(i + 1, p.tray ?: p.stickers.first(), null) }
    }

    private fun addTab(index: Int, image: String?, label: String?) {
        val selected = index == current
        val frame = FrameLayout(this).apply {
            setPadding(dp(6), dp(6), dp(6), dp(6))
            background = GradientDrawable().apply {
                cornerRadius = dp(10).toFloat()
                setColor(if (selected) (accent and 0x40FFFFFF) else Color.TRANSPARENT)
            }
            setOnClickListener {
                current = index
                buildTabs()
                showCurrent()
            }
        }
        if (image != null) {
            val iv = ImageView(this).apply { scaleType = ImageView.ScaleType.FIT_CENTER }
            loadThumb(image, iv, dp(36))
            frame.addView(iv, FrameLayout.LayoutParams(dp(36), dp(36)))
        } else {
            frame.addView(TextView(this).apply {
                text = label
                textSize = 20f
                gravity = Gravity.CENTER
            }, FrameLayout.LayoutParams(dp(36), dp(36)))
        }
        tabs.addView(frame, LinearLayout.LayoutParams(-2, -2).apply { marginEnd = dp(2) })
    }

    private fun showCurrent() {
        val items = if (current == 0) recents() else packs.getOrNull(current - 1)?.stickers ?: emptyList()
        empty.visibility = if (items.isEmpty()) View.VISIBLE else View.GONE
        empty.text = if (packs.isEmpty())
            "Nessun pacchetto. Crea o importa sticker in BenitoSticker."
        else "Ancora nessuno sticker recente."
        grid.adapter = object : BaseAdapter() {
            override fun getCount() = items.size
            override fun getItem(position: Int) = items[position]
            override fun getItemId(position: Int) = position.toLong()
            override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
                val iv = (convertView as? ImageView) ?: ImageView(this@StickerKeyboardService).apply {
                    scaleType = ImageView.ScaleType.FIT_CENTER
                    layoutParams = ViewGroup.LayoutParams(-1, dp(76))
                    setPadding(dp(4), dp(4), dp(4), dp(4))
                }
                val path = items[position]
                iv.tag = path
                iv.setImageBitmap(null)
                loadThumb(path, iv, dp(76))
                iv.setOnClickListener { send(path) }
                return iv
            }
        }
    }

    private fun loadThumb(path: String, view: ImageView, sizePx: Int) {
        val key = "$path@$sizePx"
        thumbs.get(key)?.let { view.setImageBitmap(it); return }
        view.tag = path
        io.execute {
            val bmp = try {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(path, bounds)
                var sample = 1
                while (bounds.outWidth / (sample * 2) >= sizePx) sample *= 2
                BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
            } catch (_: Exception) {
                null
            } ?: return@execute
            thumbs.put(key, bmp)
            main.post { if (view.tag == path) view.setImageBitmap(bmp) }
        }
    }

    // --- Invio ---

    private fun switchBack() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            if (!switchToPreviousInputMethod()) {
                (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager).showInputMethodPicker()
            }
        } else {
            (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager).showInputMethodPicker()
        }
    }

    private fun send(path: String) {
        addRecent(path)
        val editor = currentInputEditorInfo
        val conn = currentInputConnection
        val accepted = if (editor != null) EditorInfoCompat.getContentMimeTypes(editor) else emptyArray()
        val wantsWebp = accepted.any { ClipDescription.compareMimeTypes("image/webp", it) }
        val wantsPng = accepted.any { ClipDescription.compareMimeTypes("image/png", it) }

        try {
            val shared: Pair<File, String>? = when {
                wantsWebp -> copyForShare(File(path), "webp") to "image/webp"
                wantsPng -> toPng(File(path)) to "image/png"
                else -> null
            }
            if (shared != null && conn != null && editor != null) {
                val uri = uriFor(shared.first)
                val info = InputContentInfoCompat(uri, ClipDescription("sticker", arrayOf(shared.second)), null)
                val flags = if (Build.VERSION.SDK_INT >= 25) InputConnectionCompat.INPUT_CONTENT_GRANT_READ_URI_PERMISSION else 0
                if (InputConnectionCompat.commitContent(conn, editor, info, flags, null)) return
            }
            shareFallback(File(path), editor?.packageName)
        } catch (e: Exception) {
            Toast.makeText(this, "Sticker non inviato: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun shareDir() = File(cacheDir, "benito_keyboard").apply { mkdirs() }

    private fun copyForShare(src: File, ext: String): File {
        val out = File(shareDir(), "sticker_${src.nameWithoutExtension.hashCode().toUInt()}.$ext")
        if (!out.exists()) src.copyTo(out, overwrite = true)
        return out
    }

    private fun toPng(src: File): File {
        val out = File(shareDir(), "sticker_${src.nameWithoutExtension.hashCode().toUInt()}.png")
        if (!out.exists()) {
            val bmp = BitmapFactory.decodeFile(src.absolutePath) ?: throw IllegalStateException("immagine non leggibile")
            out.outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
        return out
    }

    private fun uriFor(file: File): Uri = FileProvider.getUriForFile(this, "$packageName.benito.files", file)

    private fun shareFallback(src: File, targetPackage: String?) {
        val file = copyForShare(src, "webp")
        val uri = uriFor(file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "image/webp"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (targetPackage != null) setPackage(targetPackage)
        }
        val intent = if (targetPackage != null && send.resolveActivity(packageManager) != null) send
        else Intent.createChooser(send.apply { setPackage(null) }, "Invia sticker")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        io.shutdownNow()
    }
}
