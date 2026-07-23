package com.lasercyber.lws.ai.model;
/**
 * Lens stain audit states for automated ai-report upload eligibility.
 */
public enum StainAuditStatus {
    CLEAN,
    STAIN_CONFIRMED,
    INTERNAL_FILTERED,
    DETECT_FAILED,
    AUTO_SUSPECTED_MISS,
    AUTO_SUSPECTED_FALSE_POSITIVE
}
