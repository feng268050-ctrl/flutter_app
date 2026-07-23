package com.lasercyber.lws.ui.bean.test;

import com.lasercyber.lws.ui.common.annotation.HexData;
import com.lasercyber.lws.ui.common.utils.hex.Hex;

/** Hex convert fixture without array fields (matches legacy {@code DeviceTest}). */
public class DeviceHexSample implements Hex {
    public Integer id;
    @HexData(size = 1)
    public Integer ctrBoardNo;
    @HexData(size = 1)
    public Integer ctrPortNo;
    @HexData(size = 1)
    public Integer devType;
    @HexData(size = 12)
    public String devName;
    @HexData(size = 1)
    public Integer spdEn;
    @HexData(size = 1)
    public Integer pwrChkEn;
    @HexData(size = 2)
    public Integer pwrLimit;
    @HexData(size = 2)
    public Integer runModelType;
    @HexData(size = 1)
    public Integer portEnable;
}
