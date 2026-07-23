package com.lasercyber.lws.ui.bean.ui;

import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;
import lombok.experimental.Accessors;

@EqualsAndHashCode(callSuper = true)
@Accessors(chain = true)
@Data
@NoArgsConstructor
public class DoubleWheelViewItem extends WheelViewItem{
    private double value;
    private long dataId;
    public DoubleWheelViewItem(String text, int type, int backGroundRes) {
        super(text, type, backGroundRes);
    }
}
