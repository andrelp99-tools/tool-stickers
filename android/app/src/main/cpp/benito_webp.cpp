// BenitoSticker: encoder WebP "one-shot" (statico e animato) usato dagli import
// (TikTok, sticker ricevuti, ecc.). Separato da libwebp_connector.cpp per non
// toccare il codice originale.
#include <jni.h>
#include <cstring>
#include <android/log.h>

#include "src/webp/encode.h"
#include "src/webp/mux.h"

#define BLOG_TAG "BenitoWebP"
#define BLOGE(...) __android_log_print(ANDROID_LOG_ERROR, BLOG_TAG, __VA_ARGS__)

static jbyteArray toJava(JNIEnv *env, const uint8_t *data, size_t size) {
    jbyteArray out = env->NewByteArray((jsize) size);
    if (out == nullptr) return nullptr;
    env->SetByteArrayRegion(out, 0, (jsize) size, reinterpret_cast<const jbyte *>(data));
    return out;
}

static bool initConfig(WebPConfig *config, float quality, bool lossless) {
    if (!WebPConfigInit(config)) return false;
    config->quality = quality;
    config->method = 4;
    config->lossless = lossless ? 1 : 0;
    config->alpha_quality = 100;
    config->exact = 0;
    return WebPValidateConfig(config) != 0;
}

extern "C" {

// Immagine statica RGBA -> WebP semplice (non animato, come richiede WhatsApp).
JNIEXPORT jbyteArray JNICALL
Java_it_andrelp99_benito_BenitoWebP_nativeEncodeStatic(
        JNIEnv *env, jobject, jbyteArray rgba, jint width, jint height,
        jfloat quality, jboolean lossless) {
    WebPConfig config;
    if (!initConfig(&config, quality, lossless)) return nullptr;

    WebPPicture pic;
    if (!WebPPictureInit(&pic)) return nullptr;
    pic.width = width;
    pic.height = height;
    pic.use_argb = 1;

    jbyte *pixels = env->GetByteArrayElements(rgba, nullptr);
    int ok = WebPPictureImportRGBA(&pic, reinterpret_cast<uint8_t *>(pixels), width * 4);
    env->ReleaseByteArrayElements(rgba, pixels, JNI_ABORT);
    if (!ok) {
        WebPPictureFree(&pic);
        return nullptr;
    }

    WebPMemoryWriter writer;
    WebPMemoryWriterInit(&writer);
    pic.writer = WebPMemoryWrite;
    pic.custom_ptr = &writer;

    jbyteArray result = nullptr;
    if (WebPEncode(&config, &pic)) {
        result = toJava(env, writer.mem, writer.size);
    } else {
        BLOGE("WebPEncode fallito: %d", pic.error_code);
    }
    WebPMemoryWriterClear(&writer);
    WebPPictureFree(&pic);
    return result;
}

// Encoder animato a stato: start -> add (un fotogramma alla volta) -> finish.
struct BenitoAnim {
    WebPAnimEncoder *enc = nullptr;
    WebPConfig config;
    int width = 0;
    int height = 0;
    int timestamp = 0;
    bool ok = true;
};

JNIEXPORT jlong JNICALL
Java_it_andrelp99_benito_BenitoWebP_nativeAnimStart(
        JNIEnv *, jobject, jint width, jint height, jfloat quality, jboolean lossless) {
    auto *a = new BenitoAnim();
    if (!initConfig(&a->config, quality, lossless)) { delete a; return 0; }
    WebPAnimEncoderOptions options;
    if (!WebPAnimEncoderOptionsInit(&options)) { delete a; return 0; }
    options.anim_params.loop_count = 0;
    a->enc = WebPAnimEncoderNew(width, height, &options);
    if (a->enc == nullptr) { delete a; return 0; }
    a->width = width;
    a->height = height;
    return reinterpret_cast<jlong>(a);
}

JNIEXPORT jboolean JNICALL
Java_it_andrelp99_benito_BenitoWebP_nativeAnimAdd(
        JNIEnv *env, jobject, jlong handle, jbyteArray rgba, jint durationMs) {
    auto *a = reinterpret_cast<BenitoAnim *>(handle);
    if (a == nullptr || !a->ok) return JNI_FALSE;
    if ((size_t) env->GetArrayLength(rgba) < (size_t) a->width * a->height * 4) {
        a->ok = false;
        return JNI_FALSE;
    }
    WebPPicture pic;
    if (!WebPPictureInit(&pic)) { a->ok = false; return JNI_FALSE; }
    pic.width = a->width;
    pic.height = a->height;
    pic.use_argb = 1;
    jbyte *pixels = env->GetByteArrayElements(rgba, nullptr);
    bool ok = WebPPictureImportRGBA(&pic, reinterpret_cast<uint8_t *>(pixels), a->width * 4) != 0;
    env->ReleaseByteArrayElements(rgba, pixels, JNI_ABORT);
    if (ok) ok = WebPAnimEncoderAdd(a->enc, &pic, a->timestamp, &a->config) != 0;
    if (!ok) BLOGE("Frame non aggiunto: %s", WebPAnimEncoderGetError(a->enc));
    WebPPictureFree(&pic);
    a->timestamp += durationMs < 8 ? 8 : durationMs;
    a->ok = ok;
    return ok ? JNI_TRUE : JNI_FALSE;
}

// Chiude l'encoder (sempre) e restituisce il WebP, o null se qualcosa è andato storto.
JNIEXPORT jbyteArray JNICALL
Java_it_andrelp99_benito_BenitoWebP_nativeAnimFinish(JNIEnv *env, jobject, jlong handle) {
    auto *a = reinterpret_cast<BenitoAnim *>(handle);
    if (a == nullptr) return nullptr;
    jbyteArray result = nullptr;
    if (a->ok && WebPAnimEncoderAdd(a->enc, nullptr, a->timestamp, nullptr)) {
        WebPData data;
        WebPDataInit(&data);
        if (WebPAnimEncoderAssemble(a->enc, &data)) {
            result = toJava(env, data.bytes, data.size);
        } else {
            BLOGE("Assemble fallito: %s", WebPAnimEncoderGetError(a->enc));
        }
        WebPDataClear(&data);
    }
    WebPAnimEncoderDelete(a->enc);
    delete a;
    return result;
}

}  // extern "C"
