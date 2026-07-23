package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import lombok.Data;

@Data
public class BaseModbusFiled implements Comparable<BaseModbusFiled>{
    /**
     * 地址
     */
    private int address;
    /**
     * 十六进制长度
     * 默认为2字节
     */
    private int hexLength=2;
    /**
     * 按 address 从小到大排序
     * @param o 目标比较对象
     * @return 负数：当前对象 address 更小（排在前）；0：address 相等；正数：当前对象 address 更大（排在后）
     */
    @Override
    public int compareTo(BaseModbusFiled o) {
        return Integer.compare(this.address, o.address);
    }
}
