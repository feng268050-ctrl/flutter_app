package com.lasercyber.lws.ui.common.utils.hex;

import com.lasercyber.lws.ui.common.annotation.HexData;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.List;

import lombok.Data;
import lombok.experimental.Accessors;

@Accessors(chain = true)
@Data
public class HexDataContent {
    /**
     * 数据
     */
    private Object data;
    /**
     * 字段信息
     */
    private Field field;
    /**
     * 描述信息
     */
    private HexData hexData;
    /**
     * 子字段
     */
    private List<HexDataContent> children;

    public static HexDataContent create(Field field, HexData hexData, Object data) {
        HexDataContent hexDataContent = new HexDataContent();
        hexDataContent.setData(data)
                .setField(field)
                .setHexData(hexData);
        return hexDataContent;
    }
    /**
     * 添加子字段
     *
     * @param child
     */
    public void pushChild(HexDataContent child) {
        if (children == null) {
            children = new ArrayList<>();
        }
        children.add(child);
    }
    public boolean hasChildField() {
        return children != null && !children.isEmpty();
    }
}
