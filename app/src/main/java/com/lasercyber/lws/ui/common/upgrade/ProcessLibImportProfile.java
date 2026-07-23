package com.lasercyber.lws.ui.common.upgrade;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Import profile for process-library xlsx: required canonical headers and optional header aliases.
 * OTA upgrades use {@link #OTA_PROCESS_LIB}; other entry points can construct a custom profile.
 */
public final class ProcessLibImportProfile {

    /**
     * OTA path: 参数名称, 工艺类型, 数据类型 must appear as column headers (after trim and alias resolution).
     */
    public static final ProcessLibImportProfile OTA_PROCESS_LIB = new ProcessLibImportProfile(
            Set.of("参数名称", "工艺类型", "数据类型"),
            createOtaAliases()
    );

    private final Set<String> requiredCanonicalHeaders;
    private final Map<String, String> aliasToCanonical;

    public ProcessLibImportProfile(Set<String> requiredCanonicalHeaders,
                                   Map<String, String> aliasToCanonical) {
        this.requiredCanonicalHeaders = Collections.unmodifiableSet(new LinkedHashSet<>(requiredCanonicalHeaders));
        this.aliasToCanonical = Collections.unmodifiableMap(new LinkedHashMap<>(aliasToCanonical));
    }

    private static Map<String, String> createOtaAliases() {
        Map<String, String> aliases = new LinkedHashMap<>();
        aliases.put("扫描频率", "摆动频率");
        aliases.put("摆动频率/扫描频率", "摆动频率");
        aliases.put("扫描宽度", "摆动宽度");
        aliases.put("摆动宽度/扫描宽度", "摆动宽度");
        aliases.put("气体关闭延迟", "关气延时");
        aliases.put("关气延时/气体关闭延迟", "关气延时");
        aliases.put("激光关闭延迟", "关光延时");
        aliases.put("关光延时/激光关闭延迟", "关光延时");
        aliases.put("缓升时长", "功率缓升");
        aliases.put("功率缓升/缓升时长", "功率缓升");
        aliases.put("缓降时长", "功率缓降");
        aliases.put("功率缓降/缓降时长", "功率缓降");
        aliases.put("送丝回抽长度", "回抽长度");
        aliases.put("回抽长度/送丝回抽长度", "回抽长度");
        aliases.put("送丝补偿长度", "补丝长度");
        aliases.put("补丝长度/送丝补偿长度", "补丝长度");
        aliases.put("补丝延迟", "补丝时延");
        aliases.put("补丝延时", "补丝时延");
        aliases.put("送丝补偿延迟", "补丝时延");
        aliases.put("补丝延迟/送丝补偿延迟", "补丝时延");
        return aliases;
    }

    public Set<String> requiredCanonicalHeaders() {
        return requiredCanonicalHeaders;
    }

    public Map<String, String> aliasToCanonical() {
        return aliasToCanonical;
    }

    /**
     * Map a trimmed header cell to the canonical key used in {@link ProcessLibColumn}.
     */
    public String canonicalHeader(String trimmedRawHeader) {
        return aliasToCanonical.getOrDefault(trimmedRawHeader, trimmedRawHeader);
    }

    /**
     * @throws IllegalArgumentException if any required canonical header is missing from the sheet
     */
    public void validateRequiredHeaders(Map<String, Integer> headerToIndex) {
        List<String> missing = new ArrayList<>();
        for (String required : requiredCanonicalHeaders) {
            if (!headerToIndex.containsKey(required)) {
                missing.add(required);
            }
        }
        if (!missing.isEmpty()) {
            throw new IllegalArgumentException(
                    "Missing required process-library columns: " + missing
                            + ". Present columns: " + headerToIndex.keySet());
        }
    }
}
