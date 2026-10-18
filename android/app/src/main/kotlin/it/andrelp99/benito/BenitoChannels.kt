package it.andrelp99.benito

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * BenitoSticker: canali Flutter <-> Android per le funzioni aggiunte nel fork.
 * Registrato con una sola riga in MainActivity.configureFlutterEngine.
 */
object BenitoChannels {
    fun register(activity: Activity, engine: FlutterEngine) {
        engine.plugins.add(BenitoPlugin())
    }
}

class BenitoPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    companion object {
        const val CHANNEL = "it.andrelp99.benito/main"
        private const val REQ_WA_TREE = 47101
        private const val PREFS = "benito"
        private const val KEY_WA_TREE = "wa_stickers_tree"
        private const val WA_STICKERS_DOC =
            "primary:Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Stickers"
        private const val MAX_FILES = 300
    }

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingTreeResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "encodeStatic" -> background(result) {
                BenitoWebP.nativeEncodeStatic(
                    call.argument<ByteArray>("rgba")!!,
                    call.argument<Int>("width")!!,
                    call.argument<Int>("height")!!,
                    (call.argument<Double>("quality") ?: 75.0).toFloat(),
                    call.argument<Boolean>("lossless") ?: false,
                ) ?: throw IllegalStateException("WebP statico non creato")
            }

            "encodeAnimated" -> background(result) {
                BenitoWebP.encodeAnimatedFromFile(
                    File(call.argument<String>("framesPath")!!),
                    call.argument<List<Int>>("durations")!!,
                    call.argument<Int>("width")!!,
                    call.argument<Int>("height")!!,
                    (call.argument<Double>("quality") ?: 60.0).toFloat(),
                ) ?: throw IllegalStateException("WebP animato non creato")
            }

            // Copia in cache gli sticker ricevuti su WhatsApp. Se la cartella non è
            // ancora autorizzata (o forcePick), apre il selettore già su "WhatsApp Stickers".
            "loadWhatsAppStickers" -> {
                val forcePick = call.argument<Boolean>("forcePick") ?: false
                val saved = savedTree()
                if (!forcePick && saved != null && hasPermission(saved)) {
                    copyTree(saved, result)
                } else {
                    openTreePicker(result)
                }
            }

            "removeBackground" -> scope.launch {
                try {
                    val path = withContext(Dispatchers.IO) {
                        BenitoBackground.removeBackground(context!!, File(call.argument<String>("path")!!))
                    }
                    result.success(path)
                } catch (e: Exception) {
                    result.error("NO_BG_FAILED", e.message ?: e.toString(), null)
                }
            }

            "keyboardEnabled" -> {
                val imm = context!!.getSystemService(Context.INPUT_METHOD_SERVICE)
                        as android.view.inputmethod.InputMethodManager
                result.success(imm.enabledInputMethodList.any {
                    it.packageName == context!!.packageName
                })
            }

            "openKeyboardSettings" -> {
                val i = Intent(android.provider.Settings.ACTION_INPUT_METHOD_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context!!.startActivity(i)
                result.success(null)
            }

            "showKeyboardPicker" -> {
                val imm = context!!.getSystemService(Context.INPUT_METHOD_SERVICE)
                        as android.view.inputmethod.InputMethodManager
                imm.showInputMethodPicker()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, block: () -> Any) {
        scope.launch {
            try {
                result.success(withContext(Dispatchers.Default) { block() })
            } catch (e: Exception) {
                result.error("BENITO_ERROR", e.message, null)
            }
        }
    }

    // --- Sticker ricevuti su WhatsApp (Storage Access Framework) ---

    private fun prefs() = context!!.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun savedTree(): Uri? = prefs().getString(KEY_WA_TREE, null)?.let(Uri::parse)

    private fun hasPermission(uri: Uri): Boolean =
        context!!.contentResolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission }

    private fun openTreePicker(result: MethodChannel.Result) {
        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("NO_ACTIVITY", "App non in primo piano", null)
            return
        }
        pendingTreeResult?.error("CANCELLED", "Nuova richiesta", null)
        pendingTreeResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(
                    DocumentsContract.EXTRA_INITIAL_URI,
                    DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", WA_STICKERS_DOC)
                )
            }
        }
        activity.startActivityForResult(intent, REQ_WA_TREE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_WA_TREE) return false
        val result = pendingTreeResult ?: return true
        pendingTreeResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null) // annullato dall'utente
            return true
        }
        try {
            context!!.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: SecurityException) {
        }
        prefs().edit().putString(KEY_WA_TREE, uri.toString()).apply()
        copyTree(uri, result)
        return true
    }

    /** Copia in cache i file immagine più recenti della cartella e ne restituisce i percorsi. */
    private fun copyTree(tree: Uri, result: MethodChannel.Result) {
        val ctx = context!!
        background(result) {
            val outDir = File(ctx.cacheDir, "benito_wa").apply {
                deleteRecursively()
                mkdirs()
            }
            val treeDoc = DocumentsContract.getTreeDocumentId(tree)
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, treeDoc)
            val files = mutableListOf<Triple<String, String, Long>>() // id, nome, data
            ctx.contentResolver.query(
                children,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                ),
                null, null, null
            )?.use { c ->
                while (c.moveToNext()) {
                    val name = c.getString(1) ?: continue
                    val mime = c.getString(2) ?: ""
                    val lower = name.lowercase()
                    if (!mime.startsWith("image/") && !lower.endsWith(".webp") &&
                        !lower.endsWith(".png") && !lower.endsWith(".gif")
                    ) continue
                    files.add(Triple(c.getString(0), name, c.getLong(3)))
                }
            }
            files.sortByDescending { it.third }
            files.take(MAX_FILES).mapNotNull { (id, name, _) ->
                try {
                    val target = File(outDir, name.replace('/', '_'))
                    ctx.contentResolver.openInputStream(
                        DocumentsContract.buildDocumentUriUsingTree(tree, id)
                    )?.use { input -> target.outputStream().use { input.copyTo(it) } }
                    target.absolutePath
                } catch (_: Exception) {
                    null
                }
            }
        }
    }
}
