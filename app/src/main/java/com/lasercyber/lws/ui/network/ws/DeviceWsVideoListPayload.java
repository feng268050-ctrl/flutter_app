package com.lasercyber.lws.ui.network.ws;

import androidx.annotation.Nullable;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;
import com.blankj.utilcode.util.GsonUtils;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Builds {@code command.video_list_response} inner structures: pagination defaults (inbound
 * {@code page} / {@code page_size}) and {@code data.list} row maps with camelCase keys aligned with
 * {@link ProcessParamsVideoVo} / {@link com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo} (excluding
 * local {@code id} and {@code videoPath}). {@code processParameters} is always present in each row map
 * as a JSON object or JSON {@code null} (parsed from {@code processParametersJson}). Parsed objects have
 * the {@code id} property removed before wire emission so servers do not receive a process-parameter row id.
 */
public final class DeviceWsVideoListPayload {
    public static final int DEFAULT_PAGE = 1;
    public static final int DEFAULT_PAGE_SIZE = 10;
    public static final int MAX_PAGE_SIZE = 100;

    private static final Pattern CALENDAR_DATE = Pattern.compile("^\\d{4}-\\d{2}-\\d{2}$");
    private static final DateTimeFormatter ISO_LOCAL_DATE = DateTimeFormatter.ISO_LOCAL_DATE;

    private DeviceWsVideoListPayload() {
    }

    /**
     * Inclusive lower bound on {@code createTime} (epoch ms) for calendar day {@code yyyy-MM-dd}
     * in the system default time zone; {@code null} when absent or invalid.
     */
    @Nullable
    public static Long startOfDayMillisFromCalendarDate(@Nullable String yyyyMmDd) {
        LocalDate date = parseCalendarDate(yyyyMmDd);
        if (date == null) {
            return null;
        }
        return date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli();
    }

    /**
     * Inclusive upper bound on {@code createTime} (epoch ms) for calendar day {@code yyyy-MM-dd}
     * in the system default time zone; {@code null} when absent or invalid.
     */
    @Nullable
    public static Long endOfDayMillisFromCalendarDate(@Nullable String yyyyMmDd) {
        LocalDate date = parseCalendarDate(yyyyMmDd);
        if (date == null) {
            return null;
        }
        return date.atTime(LocalTime.MAX).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
    }

    @Nullable
    private static LocalDate parseCalendarDate(@Nullable String yyyyMmDd) {
        if (yyyyMmDd == null) {
            return null;
        }
        String trimmed = yyyyMmDd.trim();
        if (!CALENDAR_DATE.matcher(trimmed).matches()) {
            return null;
        }
        try {
            return LocalDate.parse(trimmed, ISO_LOCAL_DATE);
        } catch (DateTimeParseException ignored) {
            return null;
        }
    }

    /**
     * @return int[0] = page (1-based), int[1] = pageSize (clamped)
     */
    public static int[] normalizePageAndSize(@Nullable JsonObject payload) {
        int page = DEFAULT_PAGE;
        int pageSize = DEFAULT_PAGE_SIZE;
        if (payload != null) {
            page = readPositiveInt(payload, "page", DEFAULT_PAGE);
            pageSize = readPositiveInt(payload, "page_size", DEFAULT_PAGE_SIZE);
        }
        if (pageSize > MAX_PAGE_SIZE) {
            pageSize = MAX_PAGE_SIZE;
        }
        return new int[]{page, pageSize};
    }

    /**
     * Optional list filters from WS {@code command.video_list_request} payload and
     * {@code GET /v1/videos} query parameters.
     */
    public static final class ListFilters {
        @Nullable
        public final Integer processType;
        @Nullable
        public final Integer materialType;
        @Nullable
        public final Long startDate;
        @Nullable
        public final Long endDate;
        /** {@code true} when {@code order} is {@code date_asc}; otherwise newest-first ({@code date_desc}). */
        public final boolean createTimeAscending;
        /**
         * Exact {@code uploadStatus} filter ({@link com.lasercyber.lws.ui.common.constant.VideoUploadStatus}).
         * {@code null} keeps legacy visibility ({@code uploadStatus != 0}).
         */
        @Nullable
        public final Integer uploadStatus;

        public ListFilters(@Nullable Integer processType,
                           @Nullable Integer materialType,
                           @Nullable Long startDate,
                           @Nullable Long endDate) {
            this(processType, materialType, startDate, endDate, false, null);
        }

        public ListFilters(@Nullable Integer processType,
                           @Nullable Integer materialType,
                           @Nullable Long startDate,
                           @Nullable Long endDate,
                           boolean createTimeAscending) {
            this(processType, materialType, startDate, endDate, createTimeAscending, null);
        }

        public ListFilters(@Nullable Integer processType,
                           @Nullable Integer materialType,
                           @Nullable Long startDate,
                           @Nullable Long endDate,
                           boolean createTimeAscending,
                           @Nullable Integer uploadStatus) {
            this.processType = processType;
            this.materialType = materialType;
            this.startDate = startDate;
            this.endDate = endDate;
            this.createTimeAscending = createTimeAscending;
            this.uploadStatus = uploadStatus;
        }
    }

    /**
     * Parses optional {@code order} ({@code date_asc} | {@code date_desc}). Unknown or absent values
     * default to {@code date_desc} (newest {@code createTime} first).
     */
    public static boolean parseCreateTimeAscending(@Nullable String order) {
        if (order == null) {
            return false;
        }
        return "date_asc".equals(order.trim());
    }

    public static ListFilters parseListFilters(@Nullable JsonObject payload) {
        if (payload == null) {
            return new ListFilters(null, null, null, null);
        }
        return new ListFilters(
                readOptionalInt(payload, "process_type"),
                readOptionalInt(payload, "material_type"),
                readOptionalCalendarDateStartMs(payload, "start_date"),
                readOptionalCalendarDateEndMs(payload, "end_date"),
                parseCreateTimeAscending(readOptionalDateString(payload, "order")),
                readOptionalInt(payload, "upload_status"));
    }

    public static List<Map<String, Object>> rowsFromVos(@Nullable List<ProcessParamsVideoVo> vos) {
        List<Map<String, Object>> out = new ArrayList<>();
        if (vos == null) {
            return out;
        }
        for (ProcessParamsVideoVo vo : vos) {
            if (vo != null) {
                out.add(voToRow(vo));
            }
        }
        return out;
    }

    /**
     * Call only from the same background executor that serves {@code command.video_list_request}
     * (Gson parse must not run on the main thread).
     */
    public static Map<String, Object> voToRow(ProcessParamsVideoVo vo) {
        Map<String, Object> m = new LinkedHashMap<>();
        // Omit local row id and filesystem path — internal only, not exposed on WS.
        m.put("processType", vo.getProcessType());
        m.put("materialType", vo.getMaterialType());
        m.put("fileSize", vo.getFileSize());
        m.put("duration", vo.getDuration());
        m.put("createTime", vo.getCreateTime());
        m.put("videoId", vo.getVideoId());
        m.put("resolution", vo.getResolution());
        m.put("uploadStatus", vo.getUploadStatus());
        m.put("uploadProgress", vo.getUploadProgress());
        m.put("coverUrl", vo.getCoverUrl());
        m.put("videoUrl", vo.getVideoUrl());
        m.put("processParameters", parseProcessParametersObjectOrNull(vo.getProcessParametersJson()));
        return m;
    }

    /**
     * Parses stored JSON text into a {@link JsonObject} for WebSocket serialization, or {@code null}
     * for JSON {@code null} when absent, blank, or not a JSON object. The {@code id} member is removed
     * from the object so {@code command.video_list_response} does not report a process-parameter id.
     */
    @Nullable
    static JsonObject parseProcessParametersObjectOrNull(@Nullable String raw) {
        if (raw == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        try {
            JsonElement el = GsonUtils.fromJson(trimmed, JsonElement.class);
            if (el != null && el.isJsonObject()) {
                JsonObject obj = el.getAsJsonObject();
                obj.remove("id");
                return obj;
            }
        } catch (Exception ignored) {
            return null;
        }
        return null;
    }

    @Nullable
    private static Integer readOptionalInt(JsonObject o, String key) {
        if (!o.has(key) || o.get(key).isJsonNull()) {
            return null;
        }
        JsonElement e = o.get(key);
        if (!e.isJsonPrimitive() || !e.getAsJsonPrimitive().isNumber()) {
            return null;
        }
        return e.getAsInt();
    }

    @Nullable
    private static Long readOptionalCalendarDateStartMs(JsonObject o, String key) {
        return startOfDayMillisFromCalendarDate(readOptionalDateString(o, key));
    }

    @Nullable
    private static Long readOptionalCalendarDateEndMs(JsonObject o, String key) {
        return endOfDayMillisFromCalendarDate(readOptionalDateString(o, key));
    }

    @Nullable
    private static String readOptionalDateString(JsonObject o, String key) {
        if (!o.has(key) || o.get(key).isJsonNull()) {
            return null;
        }
        JsonElement e = o.get(key);
        if (!e.isJsonPrimitive()) {
            return null;
        }
        JsonPrimitive p = e.getAsJsonPrimitive();
        if (!p.isString()) {
            return null;
        }
        return p.getAsString();
    }

    private static int readPositiveInt(JsonObject o, String key, int def) {
        if (o == null || !o.has(key) || o.get(key).isJsonNull()) {
            return def;
        }
        JsonElement e = o.get(key);
        if (!e.isJsonPrimitive() || !e.getAsJsonPrimitive().isNumber()) {
            return def;
        }
        long lv = e.getAsLong();
        if (lv < 1L || lv > Integer.MAX_VALUE) {
            return def;
        }
        return (int) lv;
    }
}
