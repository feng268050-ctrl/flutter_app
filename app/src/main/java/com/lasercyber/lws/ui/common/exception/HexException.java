package com.lasercyber.lws.ui.common.exception;

import lombok.Data;
import lombok.EqualsAndHashCode;

@EqualsAndHashCode(callSuper = true)
@Data
public class HexException extends RuntimeException{
    private static final long serialVersionUID = 1L;
    public HexException(String message) {
        super(message);
    }
}
