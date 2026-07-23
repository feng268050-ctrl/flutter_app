package com.lasercyber.lws.ui.common.enums;

import com.blankj.utilcode.util.StringUtils;

/**
 * 字节类型枚举
 */
public enum HexDataBiteType {
    /**
     * 默认的字节类型，使用字段的类型
     */
    DEFAULT_BITE_TYPE,
    /**
     * 使用字段类型为 int
     */
    INT_BYTE_TYPE,
    /**
     * 使用字段类型为 long
     */
    LONG_BYTE_TYPE,
    /**
     * 使用字段类型为 float
     */
    FLOAT_BYTE_TYPE,
    /**
     * 使用字段类型为 double
     */
    DOUBLE_BYTE_TYPE,
//    /**
//     * 使用字段类型为 char
//     */
//    CHAR_BYTE_TYPE,
//    /**
//     * 使用字段类型为 boolean
//     */
//    BOOLEAN_BYTE_TYPE,
    /**
     * 使用字段类型为 String
     */
    STRING_BYTE_TYPE,
    /**
     * 有符号字节
     */
    SIGNED_BYTE_TYPE,
    /**
     * 无符号字节
     */
    UNSIGNED_BYTE_TYPE,
    /**
     * 无字节类型
     */
    NONE;

    public static HexDataBiteType fileTypeToHexDataBiteType(String fileTypeClass){
        if (StringUtils.isEmpty(fileTypeClass)){
            return NONE;
        }
        return switch (fileTypeClass) {
            case "java.lang.Integer" -> INT_BYTE_TYPE;
            case "java.lang.Long" -> LONG_BYTE_TYPE;
            case "java.lang.Float" -> FLOAT_BYTE_TYPE;
            case "java.lang.Double" -> DOUBLE_BYTE_TYPE;
            case "java.lang.String" -> STRING_BYTE_TYPE;
            default -> NONE;
        };
    }
}
