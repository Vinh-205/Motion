package com.example.cam_bien_te_nga

object EmergencyCardPolicy {
    fun canReadLocked(consent: Boolean, hasName: Boolean, sosActive: Boolean): Boolean =
        consent && hasName && sosActive
}
