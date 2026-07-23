package com.lasercyber.lws.ui.network.channel;

public class DeviceCommandResult {
    private String correlationId;
    private CommandDispatchStatus status;
    private String errorCode;
    private String errorMessage;
    private DeviceChannelProtocol protocol;

    public static DeviceCommandResult dispatched(String correlationId, DeviceChannelProtocol protocol) {
        return new DeviceCommandResult()
                .setCorrelationId(correlationId)
                .setStatus(CommandDispatchStatus.DISPATCHED)
                .setProtocol(protocol);
    }

    public static DeviceCommandResult failed(String correlationId, DeviceChannelProtocol protocol, String errorCode, String errorMessage) {
        return new DeviceCommandResult()
                .setCorrelationId(correlationId)
                .setStatus(CommandDispatchStatus.FAILED)
                .setProtocol(protocol)
                .setErrorCode(errorCode)
                .setErrorMessage(errorMessage);
    }

    public String getCorrelationId() {
        return correlationId;
    }

    public DeviceCommandResult setCorrelationId(String correlationId) {
        this.correlationId = correlationId;
        return this;
    }

    public CommandDispatchStatus getStatus() {
        return status;
    }

    public DeviceCommandResult setStatus(CommandDispatchStatus status) {
        this.status = status;
        return this;
    }

    public String getErrorCode() {
        return errorCode;
    }

    public DeviceCommandResult setErrorCode(String errorCode) {
        this.errorCode = errorCode;
        return this;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public DeviceCommandResult setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
        return this;
    }

    public DeviceChannelProtocol getProtocol() {
        return protocol;
    }

    public DeviceCommandResult setProtocol(DeviceChannelProtocol protocol) {
        this.protocol = protocol;
        return this;
    }
}
