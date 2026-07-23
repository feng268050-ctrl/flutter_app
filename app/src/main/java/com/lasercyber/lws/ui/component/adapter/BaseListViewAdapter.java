package com.lasercyber.lws.ui.component.adapter;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;

import java.util.List;

/**
 * 基础的ListView适配器
 * @param <T>
 */
public abstract class BaseListViewAdapter<T> extends BaseAdapter {
    private Context context;
    private List<T> list;
    public BaseListViewAdapter(Context context, List<T> list){
        this.context=context;
        this.list=list;
    }
    @Override
    public int getCount() {
        return list.size();
    }

    @Override
    public Object getItem(int position) {
        return list.get(position);
    }

    @Override
    public long getItemId(int position) {
        return position;
    }

    public abstract View getView(int position, View convertView, ViewGroup parent);
}
