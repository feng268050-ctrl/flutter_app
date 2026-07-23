package com.lasercyber.lws.ui.bean.entity;

import java.util.List;

import lombok.Data;
import lombok.experimental.Accessors;

/**
 * 分页包装
 *
 * @param <T>
 */
@Data
@Accessors(chain = true)
public class PageData<T> {
    private int pageSize;
    private int pageNum;
    private int total;
    private List<T> list;

    public int getDataSize() {
        return list == null ? 0 : list.size();
    }
}
