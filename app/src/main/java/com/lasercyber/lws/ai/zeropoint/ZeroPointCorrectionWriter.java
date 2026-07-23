package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.zeropoint.ZeroPointCorrectionMapper;
import android.content.Context;
import android.util.Log;

import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusStartupState;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusHexData;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;

import java.util.List;

/**
 * Persists auto zero-point correction to Room and writes Modbus 0090H (×10).
 */
public final class ZeroPointCorrectionWriter {

    private static final String TAG = "ZeroPointCorrection";

    private ZeroPointCorrectionWriter() {
    }

    public static ApplyResult applyIncrementalCorrection(Context context,
                                                         int uiDelta,
                                                         long laserEventId,
                                                         double meanOffsetX,
                                                         double meanOffsetY) {
        Context appContext = context.getApplicationContext();
        AdvancedSettings setting = loadOrCreateSettings(appContext);
        int currentUi = readZeroPointUi(setting);
        int newUi = ZeroPointCorrectionMapper.applyDelta(currentUi, uiDelta);
        return persistIfChanged(appContext, setting, currentUi, newUi, laserEventId,
                meanOffsetX, meanOffsetY, "incremental", uiDelta);
    }

    /**
     * Manual Auto method 2: pulse at zero offset 0; set Zero Offset to {@code round(-offset_x / 3)}
     * (absolute, not added to current). Skips write when within position tolerance.
     */
    public static ApplyResult applyAbsoluteFromZeroBaseline(Context context,
                                                            long laserEventId,
                                                            double meanOffsetX,
                                                            double meanOffsetY) {
        Context appContext = context.getApplicationContext();
        AdvancedSettings setting = loadOrCreateSettings(appContext);
        int currentUi = readZeroPointUi(setting);
        if (ZeroPointCorrectionMapper.isWithinPositionTolerance(meanOffsetX, meanOffsetY)) {
            Log.i(TAG, "zero_point skip_write mode=absolute_zero_baseline"
                    + " eventId=" + laserEventId
                    + " meanOffsetX=" + meanOffsetX
                    + " meanOffsetY=" + meanOffsetY
                    + " reason=within_tolerance"
                    + " currentUi=" + currentUi);
            return new ApplyResult(currentUi, currentUi, 0, false);
        }
        int targetUi = ZeroPointCorrectionMapper.uiDeltaFromOffsetPx(meanOffsetX);
        return applyAbsoluteCorrection(appContext, setting, currentUi, targetUi, laserEventId,
                meanOffsetX, meanOffsetY);
    }

    /**
     * Sets Zero Offset to {@code targetUi} (clamped). Prefer
     * {@link #applyAbsoluteFromZeroBaseline} for manual Auto method 2.
     */
    public static ApplyResult applyAbsoluteCorrection(Context context,
                                                      int targetUi,
                                                      long laserEventId,
                                                      double meanOffsetX,
                                                      double meanOffsetY) {
        Context appContext = context.getApplicationContext();
        AdvancedSettings setting = loadOrCreateSettings(appContext);
        int currentUi = readZeroPointUi(setting);
        return applyAbsoluteCorrection(appContext, setting, currentUi,
                ZeroPointCorrectionMapper.clamp(targetUi), laserEventId, meanOffsetX, meanOffsetY);
    }

    private static ApplyResult applyAbsoluteCorrection(Context appContext,
                                                       AdvancedSettings setting,
                                                       int currentUi,
                                                       int newUi,
                                                       long laserEventId,
                                                       double meanOffsetX,
                                                       double meanOffsetY) {
        int uiDelta = newUi - currentUi;
        return persistIfChanged(appContext, setting, currentUi, newUi, laserEventId,
                meanOffsetX, meanOffsetY, "absolute", uiDelta);
    }

    private static AdvancedSettings loadOrCreateSettings(Context appContext) {
        AdvancedSettings setting = AppDatabase.getInstance(appContext).advancedSettingsDao().selectOne();
        if (setting == null) {
            setting = DefaultValueUtils.createDefaultAdvancedSettings();
            long id = AppDatabase.getInstance(appContext).advancedSettingsDao().insert(setting);
            setting.setId((int) id);
        }
        return setting;
    }

    private static int readZeroPointUi(AdvancedSettings setting) {
        return setting.getZeroPointCorrection() == null
                ? 0
                : setting.getZeroPointCorrection().intValue();
    }

    private static ApplyResult persistIfChanged(Context appContext,
                                                AdvancedSettings setting,
                                                int currentUi,
                                                int newUi,
                                                long laserEventId,
                                                double meanOffsetX,
                                                double meanOffsetY,
                                                String mode,
                                                int uiDelta) {
        if (newUi == currentUi && uiDelta != 0) {
            Log.i(TAG, "zero_point clamped mode=" + mode
                    + " eventId=" + laserEventId
                    + " meanOffsetX=" + meanOffsetX
                    + " meanOffsetY=" + meanOffsetY
                    + " uiDelta=" + uiDelta
                    + " currentUi=" + currentUi);
        }

        if (uiDelta == 0 || newUi == currentUi) {
            Log.i(TAG, "zero_point skip_write mode=" + mode
                    + " eventId=" + laserEventId
                    + " meanOffsetX=" + meanOffsetX
                    + " meanOffsetY=" + meanOffsetY
                    + " uiDelta=" + uiDelta
                    + " currentUi=" + currentUi);
            return new ApplyResult(currentUi, newUi, uiDelta, false);
        }

        setting.setZeroPointCorrection((double) newUi);
        AppDatabase.getInstance(appContext).advancedSettingsDao().update(setting);

        if (ModbusStartupState.isAvailable()) {
            List<ModbusHexData> writeDeviceSetting = ModbusFiledBuilder.doCreateWriteDeviceSetting(setting);
            ModbusManagerRtu.get().writeRegisters(writeDeviceSetting);
        } else {
            Log.w(TAG, "zero_point modbus_unavailable mode=" + mode
                    + " eventId=" + laserEventId
                    + " persisted newUi=" + newUi);
        }

        Log.i(TAG, "zero_point applied mode=" + mode
                + " eventId=" + laserEventId
                + " meanOffsetX=" + meanOffsetX
                + " meanOffsetY=" + meanOffsetY
                + " uiDelta=" + uiDelta
                + " currentUi=" + currentUi
                + " newUi=" + newUi);
        return new ApplyResult(currentUi, newUi, uiDelta, true);
    }

    public static final class ApplyResult {
        public final int currentUi;
        public final int newUi;
        public final int uiDelta;
        public final boolean changed;

        private ApplyResult(int currentUi, int newUi, int uiDelta, boolean changed) {
            this.currentUi = currentUi;
            this.newUi = newUi;
            this.uiDelta = uiDelta;
            this.changed = changed;
        }
    }
}
