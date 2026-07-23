package com.lasercyber.lws.ui.network.channel;

public final class DeviceChannelValidator {
    private DeviceChannelValidator() {
    }

    public static String validate(DeviceDataEvent event) {
        if (event == null) {
            return "event_null";
        }
        if (isEmpty(event.getCorrelationId())) {
            return "missing_correlation_id";
        }
        if (isEmpty(event.getPayload())) {
            return "missing_payload";
        }
        if (event.getTimestamp() <= 0) {
            return "invalid_timestamp";
        }
        if (event.getSourceProtocol() == null) {
            return "missing_source_protocol";
        }
        return null;
    }

    public static String validate(DeviceCommandRequest request) {
        if (request == null) {
            return "request_null";
        }
        if (isEmpty(request.getCorrelationId())) {
            return "missing_correlation_id";
        }
        if (isEmpty(request.getPayload())) {
            return "missing_payload";
        }
        if (isEmpty(request.getTargetTopic())) {
            return "missing_target_topic";
        }
        return null;
    }

    private static boolean isEmpty(String value) {
        return value == null || value.trim().isEmpty();
    }
}
