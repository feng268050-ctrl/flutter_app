package com.lasercyber.lws.ui.network.channel;

public class DeviceCommandRequest {
    private String deviceId;
    private String commandType;
    private String payload;
    private String correlationId;
    private long timestamp;
    private DeviceChannelProtocol sourceProtocol;
    private String targetTopic;
    private int timeoutMs = 10_000;

    public String getDeviceId() {
        return deviceId;
    }

    public DeviceCommandRequest setDeviceId(String deviceId) {
        this.deviceId = deviceId;
        return this;
    }

    public String getCommandType() {
        return commandType;
    }

    public DeviceCommandRequest setCommandType(String commandType) {
        this.commandType = commandType;
        return this;
    }

    public String getPayload() {
        return payload;
    }

    public DeviceCommandRequest setPayload(String payload) {
        this.payload = payload;
        return this;
    }

    public String getCorrelationId() {
        return correlationId;
    }

    public DeviceCommandRequest setCorrelationId(String correlationId) {
        this.correlationId = correlationId;
        return this;
    }

    public long getTimestamp() {
        return timestamp;
    }

    public DeviceCommandRequest setTimestamp(long timestamp) {
        this.timestamp = timestamp;
        return this;
    }

    public DeviceChannelProtocol getSourceProtocol() {
        return sourceProtocol;
    }

    public DeviceCommandRequest setSourceProtocol(DeviceChannelProtocol sourceProtocol) {
        this.sourceProtocol = sourceProtocol;
        return this;
    }

    public String getTargetTopic() {
        return targetTopic;
    }

    public DeviceCommandRequest setTargetTopic(String targetTopic) {
        this.targetTopic = targetTopic;
        return this;
    }

    public int getTimeoutMs() {
        return timeoutMs;
    }

    public DeviceCommandRequest setTimeoutMs(int timeoutMs) {
        this.timeoutMs = timeoutMs;
        return this;
    }
}
