package com.lasercyber.lws.ui.common.rx.modbus;

import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.common.config.ControlCardCommAlarmMode;

import java.util.ArrayDeque;

/**
 * Recent Modbus segment poll outcomes for C001 ({@link ControlCardCommAlarmMode}).
 */
final class ModbusSegmentReadHealth {

    @VisibleForTesting
    static final int WINDOW_SIZE = 5;

    @VisibleForTesting
    static final int FAILURE_THRESHOLD = 3;

    private final ArrayDeque<Boolean> outcomes = new ArrayDeque<>(WINDOW_SIZE);

    void recordOutcome(boolean success) {
        if (outcomes.size() >= WINDOW_SIZE) {
            outcomes.removeFirst();
        }
        outcomes.addLast(success);
    }

    boolean isFault(ControlCardCommAlarmMode mode) {
        if (outcomes.isEmpty()) {
            return false;
        }
        if (mode == ControlCardCommAlarmMode.IMMEDIATE) {
            return !Boolean.TRUE.equals(outcomes.getLast());
        }
        int failures = 0;
        for (Boolean success : outcomes) {
            if (!success) {
                failures++;
            }
        }
        return failures >= FAILURE_THRESHOLD;
    }

    void resetForTest() {
        outcomes.clear();
    }
}
