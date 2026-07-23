package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.JsonObject;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersNameData;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;
import com.lasercyber.lws.ui.common.state.ProcessParametersSnapshotStore;
import com.lasercyber.lws.ui.network.ws.DeviceWsProcessParametersPayload;
import com.lasercyber.lws.ui.network.ws.DeviceWsRowId;
import com.lasercyber.lws.ui.repository.ProcessParametersDataDao;

import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Shared engineer-mode process library operations for WebSocket and local HTTP.
 */
public final class ProcessParametersRemoteService {
    private ProcessParametersRemoteService() {
    }

    @NonNull
    public static List<Map<String, Object>> listLibrary(
            @NonNull ProcessParametersDataDao dao,
            int processType,
            boolean stringIds
    ) {
        List<ProcessParametersData> rows = dao.selectEngineerAllSync(processType);
        List<Map<String, Object>> out = new java.util.ArrayList<>();
        if (rows == null) {
            return out;
        }
        for (ProcessParametersData row : rows) {
            Map<String, Object> map = DeviceWsProcessParametersPayload.entityToMap(row, stringIds);
            if (map != null) {
                out.add(map);
            }
        }
        return out;
    }

    @Nullable
    public static ProcessParametersData getById(@NonNull ProcessParametersDataDao dao, long id) {
        ProcessParametersData row = dao.selectByIdSync(id);
        if (row == null || !DeviceWsProcessParametersPayload.isEngineerMode(row.getDataType())) {
            return null;
        }
        return row;
    }

    @NonNull
    public static MutationResult create(
            @NonNull ProcessParametersDataDao dao,
            @NonNull ProcessParametersData incoming
    ) {
        Integer processType = incoming.getProcessType();
        if (processType == null) {
            return MutationResult.fail("missing_process_type");
        }
        incoming.setId(null);
        incoming.setDataType(ProcessDataType.ENGINEER_MODE_DATA);
        incoming.setProcessType(processType);
        long id = dao.insert(incoming);
        incoming.setId(id);
        maybeRefreshActivePreset(incoming);
        return MutationResult.ok(id);
    }

    @NonNull
    public static MutationResult createFromJson(
            @NonNull ProcessParametersDataDao dao,
            @NonNull JsonObject payload,
            boolean wsFieldNames
    ) {
        return create(dao, DeviceWsProcessParametersPayload.fromPayload(payload, wsFieldNames));
    }

    @NonNull
    public static MutationResult update(
            @NonNull ProcessParametersDataDao dao,
            long id,
            @NonNull ProcessParametersData patch
    ) {
        ProcessParametersData existing = dao.selectByIdSync(id);
        if (existing == null) {
            return MutationResult.fail("not_found");
        }
        if (!DeviceWsProcessParametersPayload.isEngineerMode(existing.getDataType())) {
            return MutationResult.fail("not_engineer_mode");
        }
        applyPatch(existing, patch);
        existing.setId(id);
        int updated = dao.update(existing);
        if (updated <= 0) {
            return MutationResult.fail("update_failed");
        }
        maybeRefreshActivePreset(existing);
        return MutationResult.ok(id);
    }

    @NonNull
    public static MutationResult updateFromJson(
            @NonNull ProcessParametersDataDao dao,
            long id,
            @NonNull JsonObject payload,
            boolean wsFieldNames
    ) {
        ProcessParametersData patch = DeviceWsProcessParametersPayload.fromPayload(payload, wsFieldNames);
        return update(dao, id, patch);
    }

    @NonNull
    public static MutationResult delete(@NonNull ProcessParametersDataDao dao, long id) {
        ProcessParametersData existing = dao.selectByIdSync(id);
        if (existing == null) {
            return MutationResult.fail("not_found");
        }
        if (existing.getDataType() == null
                || !ProcessDataType.isEngineerModeDataType(existing.getDataType())) {
            return MutationResult.fail("cannot_delete_non_engineer");
        }
        int deleted = dao.deleteById(id);
        if (deleted <= 0) {
            return MutationResult.fail("delete_failed");
        }
        return MutationResult.ok(id);
    }

    @NonNull
    public static MutationResult setDefault(@NonNull ProcessParametersDataDao dao, long id) {
        ProcessParametersData row = dao.selectByIdSync(id);
        if (row == null) {
            return MutationResult.fail("not_found");
        }
        if (!DeviceWsProcessParametersPayload.isEngineerMode(row.getDataType())) {
            return MutationResult.fail("not_engineer_mode");
        }
        Integer processType = row.getProcessType();
        if (processType == null) {
            return MutationResult.fail("missing_process_type");
        }
        String cacheKey = CacheKey.ENGINEER_DATA_CACHE_KEY + processType;
        MemoryCacheManager.getInstance().putSerializable(cacheKey, row);
        ProcessParametersSnapshotStore.update(row);
        return MutationResult.ok(id);
    }

    private static void applyPatch(@NonNull ProcessParametersData target, @NonNull ProcessParametersData patch) {
        if (patch.getName() != null) {
            target.setName(patch.getName());
        }
        if (patch.getMaterialType() != null) {
            target.setMaterialType(patch.getMaterialType());
        }
        if (patch.getMaterialName() != null) {
            target.setMaterialName(patch.getMaterialName());
        }
        if (patch.getThickness() != null) {
            target.setThickness(patch.getThickness());
        }
        if (patch.getLaserPower() != null) {
            target.setLaserPower(patch.getLaserPower());
        }
        if (patch.getPerforationPower() != null) {
            target.setPerforationPower(patch.getPerforationPower());
        }
        if (patch.getSwingFrequency() != null) {
            target.setSwingFrequency(patch.getSwingFrequency());
        }
        if (patch.getLaserFrequency() != null) {
            target.setLaserFrequency(patch.getLaserFrequency());
        }
        if (patch.getPerforationFrequency() != null) {
            target.setPerforationFrequency(patch.getPerforationFrequency());
        }
        if (patch.getSwingWidth() != null) {
            target.setSwingWidth(patch.getSwingWidth());
        }
        if (patch.getBlowDelay() != null) {
            target.setBlowDelay(patch.getBlowDelay());
        }
        if (patch.getCloseAirDelay() != null) {
            target.setCloseAirDelay(patch.getCloseAirDelay());
        }
        if (patch.getCloseLightDelay() != null) {
            target.setCloseLightDelay(patch.getCloseLightDelay());
        }
        if (patch.getFillDelay() != null) {
            target.setFillDelay(patch.getFillDelay());
        }
        if (patch.getWireFeedingDelay() != null) {
            target.setWireFeedingDelay(patch.getWireFeedingDelay());
        }
        if (patch.getPerforationDuration() != null) {
            target.setPerforationDuration(patch.getPerforationDuration());
        }
        if (patch.getPointWeldingInterval() != null) {
            target.setPointWeldingInterval(patch.getPointWeldingInterval());
        }
        if (patch.getPointWeldingDuration() != null) {
            target.setPointWeldingDuration(patch.getPointWeldingDuration());
        }
        if (patch.getPowerRampUp() != null) {
            target.setPowerRampUp(patch.getPowerRampUp());
        }
        if (patch.getPowerRampDown() != null) {
            target.setPowerRampDown(patch.getPowerRampDown());
        }
        if (patch.getWireFeedSpeed() != null) {
            target.setWireFeedSpeed(patch.getWireFeedSpeed());
        }
        if (patch.getRetractLength() != null) {
            target.setRetractLength(patch.getRetractLength());
        }
        if (patch.getRetractSpeed() != null) {
            target.setRetractSpeed(patch.getRetractSpeed());
        }
        if (patch.getFillLength() != null) {
            target.setFillLength(patch.getFillLength());
        }
        if (patch.getLaserDutyCycle() != null) {
            target.setLaserDutyCycle(patch.getLaserDutyCycle());
        }
        if (patch.getPerforationDutyCycle() != null) {
            target.setPerforationDutyCycle(patch.getPerforationDutyCycle());
        }
        if (patch.getGear() != null) {
            target.setGear(patch.getGear());
        }
        if (patch.getOriginId() != null) {
            target.setOriginId(patch.getOriginId());
        }
    }

    private static void maybeRefreshActivePreset(@NonNull ProcessParametersData row) {
        Integer processType = row.getProcessType();
        Long id = row.getId();
        if (processType == null || id == null) {
            return;
        }
        String cacheKey = CacheKey.ENGINEER_DATA_CACHE_KEY + processType;
        ProcessParametersData cached = MemoryCacheManager.getInstance().getSerializable(cacheKey);
        if (cached != null && Objects.equals(cached.getId(), id)) {
            MemoryCacheManager.getInstance().putSerializable(cacheKey, row);
            ProcessParametersSnapshotStore.update(row);
        }
    }

    public static final class MutationResult {
        public final boolean success;
        @Nullable
        public final Long id;
        @NonNull
        public final String message;

        private MutationResult(boolean success, @Nullable Long id, @NonNull String message) {
            this.success = success;
            this.id = id;
            this.message = message;
        }

        @NonNull
        public static MutationResult ok(long id) {
            return new MutationResult(true, id, "");
        }

        @NonNull
        public static MutationResult fail(@NonNull String message) {
            return new MutationResult(false, null, message);
        }
    }
}
