package com.lasercyber.lws.ui.common.handler;

import androidx.annotation.NonNull;

import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/**
 * Tracks which alarm codes already have an open <em>log episode</em> (inserted or updated in
 * {@code warn_table}). Independent of popup / {@link com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController}.
 * <p>
 * Rules:
 * <ul>
 *   <li>INSERT only on rising edge (fault appears and no row in the DB dedup window)</li>
 *   <li>UPDATE when a row exists in the dedup window</li>
 *   <li>After operator clears the log, ongoing faults stay tracked and are not re-inserted</li>
 *   <li>Falling edge ({@link #notifyFaultCleared}) allows a future re-occurrence to INSERT again</li>
 * </ul>
 */
public final class WarnLogEpisodeTracker {

    private static final Set<String> ongoingEpisodes =
            Collections.synchronizedSet(new HashSet<>());

    private WarnLogEpisodeTracker() {
    }

    /**
     * @return {@code true} when this code was tracked as an ongoing log episode (cleared log row may be written)
     */
    public static boolean notifyFaultCleared(@NonNull String code) {
        return ongoingEpisodes.remove(code);
    }

    public static void markOngoingEpisode(@NonNull String code) {
        ongoingEpisodes.add(code);
    }

    /**
     * @param activeCodes      alarm codes active on this poll
     * @param codesWithDbRows  codes that already have a row in the persistence dedup window
     */
    @NonNull
    public static Set<String> resolveInsertCodes(@NonNull Collection<String> activeCodes,
                                                 @NonNull Collection<String> codesWithDbRows) {
        Set<String> active = new HashSet<>(activeCodes);
        ongoingEpisodes.removeIf(code -> !active.contains(code));

        Set<String> insertCodes = new HashSet<>();
        Set<String> dbCodes = new HashSet<>(codesWithDbRows);
        for (String code : active) {
            if (ongoingEpisodes.contains(code)) {
                continue;
            }
            ongoingEpisodes.add(code);
            if (!dbCodes.contains(code)) {
                insertCodes.add(code);
            }
        }
        return insertCodes;
    }

    static void resetForTest() {
        ongoingEpisodes.clear();
    }
}
