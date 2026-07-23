package com.lasercyber.lws.ui.bean.test;

import com.lasercyber.lws.ui.common.annotation.HexData;
import com.lasercyber.lws.ui.common.utils.hex.Hex;

public class User implements Hex {
    @HexData(size = 12)
    public String userName;
    @HexData(size = 1)
    public Integer age;
}
