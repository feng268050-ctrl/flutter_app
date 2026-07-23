package com.lasercyber.lws.ui.common.annotation;

import com.lasercyber.lws.ui.common.enums.HexDataBiteType;
import com.lasercyber.lws.ui.common.enums.HexDataFiledType;
import com.lasercyber.lws.ui.common.utils.hex.Hex;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 十六进制数据转换注解
 */
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.FIELD)
public @interface HexData {
    /**
     * 字节大小
     * @return
     */
    int size();
    /**
     * 字节类型
     * @return
     */
    HexDataBiteType biteType() default HexDataBiteType.DEFAULT_BITE_TYPE;

    /**
     * 字段排序
     * @return
     */
    int order() default 0;
    /**
     * 字段类型
     * @return
     */
    HexDataFiledType filedType() default HexDataFiledType.DATA_FILED;

    /**
     * 字段名称，默认为当前字段的名
     * @return
     */
    String fileName() default "";

    /**
     * 上级字段名称，默认为空
     * @return
     */
    String parentFileName() default "";

    /**
     * 子字段类
     * @return
     */
    Class<? extends Hex> childClazz() default Hex.class;
}
