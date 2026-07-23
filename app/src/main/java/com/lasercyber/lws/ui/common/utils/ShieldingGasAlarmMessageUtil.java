package com.lasercyber.lws.ui.common.utils;

import android.content.Context;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;

import java.util.ArrayList;
import java.util.List;
/**
 * User-facing copy and log lines for A001 (control-card gas path alarms).
 */
public final class ShieldingGasAlarmMessageUtil {

    private static final String LOG_PREFIX = "A001";

    private ShieldingGasAlarmMessageUtil() {
    }

    public static boolean hasActiveAlarm(DeviceStatus deviceStatus) {
        if (deviceStatus == null) {
            return false;
        }
        return deviceStatus.isPressureAlarm()
                || deviceStatus.isControllerCardAirIntakePressureWarning()
                || deviceStatus.isControllerCardCommunicationFailurePressureSensor()
                || deviceStatus.isControllerCardExternalFlashMalfunction();
    }

    /** Dialog title is always the generic shielding-gas alarm label. */
    public static String buildDialogTitle(Context context) {
        return context.getString(R.string.shielding_gas_alarm_title);
    }

    /** Consumer-facing dialog body: reason list + generic guidance. */
    public static String buildDialogContent(Context context, DeviceStatus deviceStatus) {
        List<String> causes = collectCauseLabels(context, deviceStatus);
        if (causes.isEmpty()) {
            return context.getString(R.string.shielding_gas_alarm_content);
        }
        StringBuilder body = new StringBuilder();
        body.append(context.getString(R.string.shielding_gas_alarm_reason_header));
        for (String cause : causes) {
            body.append('\n').append(context.getString(R.string.shielding_gas_alarm_reason_bullet, cause));
        }
        body.append("\n\n");
        body.append(context.getString(R.string.shielding_gas_alarm_content));
        return body.toString();
    }

    /** Alarm history list (same plain language as the dialog). */
    public static String buildWarnLogContent(Context context, DeviceStatus deviceStatus) {
        String causes = joinCauseLabels(context, deviceStatus, "、");
        if (causes.isEmpty()) {
            return context.getString(R.string.shielding_gas_alarm_content);
        }
        return context.getString(R.string.shielding_gas_alarm_warn_log_content, causes);
    }

    /** Logcat line for service; same plain-language causes as the dialog. */
    public static String buildLogMessage(Context context, DeviceStatus deviceStatus) {
        String causes = joinCauseLabels(context, deviceStatus, "、");
        if (causes.isEmpty()) {
            return LOG_PREFIX + " " + context.getString(R.string.shielding_gas_alarm_title);
        }
        return context.getString(R.string.shielding_gas_alarm_log_message, causes);
    }

    public static String buildEngineerCheckMessage(Context context, DeviceStatus deviceStatus) {
        String causes = joinCauseLabels(context, deviceStatus, "、");
        if (causes.isEmpty()) {
            return context.getString(R.string.abnormal_atmospheric_pressure_text);
        }
        return context.getString(R.string.shielding_gas_alarm_engineer_check_message, causes);
    }

    private static String joinCauseLabels(Context context, DeviceStatus deviceStatus, String delimiter) {
        return String.join(delimiter, collectCauseLabels(context, deviceStatus));
    }

    private static List<String> collectCauseLabels(Context context, DeviceStatus deviceStatus) {
        List<String> labels = new ArrayList<>(4);
        if (deviceStatus == null) {
            return labels;
        }
        if (deviceStatus.isPressureAlarm()) {
            labels.add(context.getString(R.string.shielding_gas_alarm_cause_blow_pressure));
        }
        if (deviceStatus.isControllerCardAirIntakePressureWarning()) {
            labels.add(context.getString(R.string.shielding_gas_alarm_cause_inlet_pressure));
        }
        if (deviceStatus.isControllerCardCommunicationFailurePressureSensor()) {
            labels.add(context.getString(R.string.shielding_gas_alarm_cause_pressure_check));
        }
        if (deviceStatus.isControllerCardExternalFlashMalfunction()) {
            labels.add(context.getString(R.string.shielding_gas_alarm_cause_device_service));
        }
        return labels;
    }
}
