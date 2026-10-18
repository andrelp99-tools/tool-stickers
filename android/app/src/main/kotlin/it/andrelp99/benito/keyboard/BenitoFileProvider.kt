package it.andrelp99.benito.keyboard

import androidx.core.content.FileProvider

/** Sottoclasse dedicata, per non scontrarsi con i FileProvider dei plugin nel manifest. */
class BenitoFileProvider : FileProvider()
