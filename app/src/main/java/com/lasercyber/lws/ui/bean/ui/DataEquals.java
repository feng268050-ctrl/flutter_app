package com.lasercyber.lws.ui.bean.ui;

/**
 * 对比数据是否变化的接口
 * @param <T>
 */
public interface DataEquals <T>{
    /**
     * 判断数据是否相等
     * @param data 新数据
     * @return
     */
    boolean dataChange(T data);
}
