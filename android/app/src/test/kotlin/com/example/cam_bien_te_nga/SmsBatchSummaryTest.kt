package com.example.cam_bien_te_nga

import org.junit.Assert.*
import org.junit.Test

class SmsBatchSummaryTest {
    @Test fun mixedFailureDoesNotHidePendingOrSuccessfulRecipients() {
        assertEquals("sending", SmsBatchSummary.status(listOf("failed", "sending", "sent")))
        assertEquals("partial", SmsBatchSummary.status(listOf("failed", "delivered", "sent")))
        assertTrue(SmsBatchSummary.detail(listOf("failed", "delivered", "sent")).contains("2/3"))
    }
    @Test fun sentIsDifferentFromDelivered() {
        assertEquals("sent", SmsBatchSummary.status(listOf("sent", "delivered")))
        assertEquals("delivered", SmsBatchSummary.status(listOf("delivered", "delivered")))
    }
    @Test fun unknownAndDryRunAreNeverSuccess() {
        assertEquals("unknown", SmsBatchSummary.status(listOf("unknown", "unknown")))
        assertEquals("partial", SmsBatchSummary.status(listOf("sent", "unknown")))
        assertEquals("dryRun", SmsBatchSummary.status(listOf("dryRun", "dryRun")))
        assertEquals("failed", SmsBatchSummary.status(emptyList()))
    }
}
