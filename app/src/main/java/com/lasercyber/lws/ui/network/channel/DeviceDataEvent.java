package com.lasercyber.lws.ui.network.channel;

public class DeviceDataEvent {
    private String deviceId;
    private String eventType;
    private String payload;
    private long timestamp;
    private String correlationId;
    private DeviceChannelProtocol sourceProtocol;

    public String getDeviceId() {
        return deviceId;
    }

    public DeviceDataEvent setDeviceId(String deviceId) {
        this.deviceId = deviceId;
        return this;
    }

    public String getEventType() {
        return eventType;
    }

    public DeviceDataEvent setEventType(String eventType) {
        this.eventType = eventType;
        return this;
    }

    public String getPayload() {
        return payload;
    }

    public DeviceDataEvent setPayload(String payload) {
        this.payload = payload;
        return this;
    }

    public long getTimestamp() {
        return timestamp;
    }

    public DeviceDataEvent setTimestamp(long timestamp) {
        this.timestamp = timestamp;
        return this;
    }

    public String getCorrelationId() {
        return correlationId;
    }

    public DeviceDataEvent setCorrelationId(String correlationId) {
        this.correlationId = correlationId;
        return this;
    }

    public DeviceChannelProtocol getSourceProtocol() {
        return sourceProtocol;
    }

    public DeviceDataEvent setSourceProtocol(DeviceChannelProtocol sourceProtocol) {
        this.sourceProtocol = sourceProtocol;
        return this;
    }
}
