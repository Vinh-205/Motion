package com.example.cam_bien_te_nga
import org.junit.Assert.*
import org.junit.Test
class SmsFailureTest {
    @Test fun errorsPreserveAndroidAndModemCodes() {
        assertTrue(SmsFailure.describe(4, 38).contains("modem: 38"))
        assertTrue(SmsFailure.describe(2).contains("máy bay"))
        assertTrue(SmsFailure.describe(99).contains("99"))
        assertTrue(SmsFailure.describe(5).contains("giới hạn"))
    }
}
