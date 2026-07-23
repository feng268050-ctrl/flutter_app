package com.lasercyber.lws.ui.common.utils.json;

import com.blankj.utilcode.util.GsonUtils;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.lasercyber.lws.ui.common.constant.GsonConstants;

public class GsonInitUtils {
    private static final String DATE_FORMAT = "yyyy-MM-dd HH:mm:ss";

    /**
     * 初始化Gson
     */
    public static void initGson() {
        // 1. 构建自定义Gson，配置时间格式
        Gson gson = new GsonBuilder()
                // 配置Date类型的序列化/反序列化格式
                .setDateFormat(DATE_FORMAT)
                // 可选：序列化时忽略null字段
                .serializeNulls()
                // 可选：格式化输出（仅调试用，生产环境关闭）
                // .setPrettyPrinting()
                .create();
        GsonUtils.setGson(GsonConstants.LASER_GSON, gson);
    }

    public static Gson getGson() {
        return GsonUtils.getGson(GsonConstants.LASER_GSON);
    }
}
