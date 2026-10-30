package com.example.cam_bien_te_nga

import org.junit.Assert.assertEquals
import org.junit.Test

class EmergencyCardPolicyTest {
    @Test fun lockedAccessRequiresConsentNameAndActiveSos() {
        for (consent in listOf(false, true)) for (name in listOf(false, true)) for (sos in listOf(false, true)) {
            assertEquals(consent && name && sos, EmergencyCardPolicy.canReadLocked(consent, name, sos))
        }
    }
}
