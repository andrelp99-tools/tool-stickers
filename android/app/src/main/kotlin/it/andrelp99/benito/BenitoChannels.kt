package it.andrelp99.benito

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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
    const val CHANNEL = "it.andrelp99.benito/main"
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "encodeStatic" -> scope.launch {
                    try {
                        val out = withContext(Dispatchers.Default) {
                            BenitoWebP.nativeEncodeStatic(
                                call.argument<ByteArray>("rgba")!!,
                                call.argument<Int>("width")!!,
                                call.argument<Int>("height")!!,
                                (call.argument<Double>("quality") ?: 75.0).toFloat(),
                                call.argument<Boolean>("lossless") ?: false,
                            )
                        }
                        if (out == null) result.error("ENCODE_FAILED", "WebP statico non creato", null)
                        else result.success(out)
                    } catch (e: Exception) {
                        result.error("ENCODE_FAILED", e.message, null)
                    }
                }

                "encodeAnimated" -> scope.launch {
                    try {
                        val out = withContext(Dispatchers.Default) {
                            BenitoWebP.encodeAnimatedFromFile(
                                File(call.argument<String>("framesPath")!!),
                                call.argument<List<Int>>("durations")!!,
                                call.argument<Int>("width")!!,
                                call.argument<Int>("height")!!,
                                (call.argument<Double>("quality") ?: 60.0).toFloat(),
                            )
                        }
                        if (out == null) result.error("ENCODE_FAILED", "WebP animato non creato", null)
                        else result.success(out)
                    } catch (e: Exception) {
                        result.error("ENCODE_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
