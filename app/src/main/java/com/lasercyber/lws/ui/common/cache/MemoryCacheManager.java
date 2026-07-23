package com.lasercyber.lws.ui.common.cache;

import android.graphics.Bitmap;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.util.LruCache;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.ObjectOutputStream;
import java.io.Serializable;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * 封装官方的LruCache
 */
public class MemoryCacheManager {
    private static final String TAG = LogTAGConstant.MemoryCacheManager;
    // 单例模式：全局唯一缓存实例（避免多实例占用内存）
    private static volatile MemoryCacheManager INSTANCE;
    // LruCache 实例：key 为 String 类型，value 为 Object（支持任意数据类型）
    private final LruCache<String, Object> mLruCache;
    // UI线程Handler
    private final Handler mUiHandler;
    /**
     * 缓存数据变化监听器列表
     * key:缓存key
     * value:缓存数据变化监听器
     */
    private final Map<String, CopyOnWriteArrayList<OnCacheChangedListener>> listenerMap = new HashMap<>();
    // 私有构造方法：初始化 LruCache
    private MemoryCacheManager() {
        // 1. 计算最大缓存容量（建议：应用最大内存的 1/8，避免 OOM）
        // 应用最大内存：Runtime.getRuntime().maxMemory()（单位：字节）
        long maxMemory = Runtime.getRuntime().maxMemory();
        int maxCacheSize = (int) (maxMemory / 8); // 示例：最大缓存为应用内存的 1/8
        // 若需更直观（如固定 20MB）：int maxCacheSize = 20 * 1024 * 1024;（字节）
        mUiHandler = new Handler(Looper.getMainLooper());
        // 2. 初始化 LruCache
        mLruCache = new LruCache<String, Object>(maxCacheSize) {
            /**
             * 重写 sizeOf：计算每个缓存项的大小（单位必须与 maxCacheSize 一致，此处为字节）
             * @param key 缓存键
             * @param value 缓存值（需根据实际类型计算大小）
             * @return 缓存项大小（字节）
             */
            @Override
            protected int sizeOf(String key, Object value) {
                if (value instanceof String) {
                    // 计算 String 大小（UTF-8 编码）
                    return ((String) value).getBytes(StandardCharsets.UTF_8).length;
                } else if (value instanceof Bitmap) {
                    // 计算 Bitmap 大小（关键：避免 Bitmap 占用过多内存）
                    // Bitmap 大小 = 宽度 * 高度 * 每个像素占用字节数
                    Bitmap bitmap = (Bitmap) value;
                    // getRowBytes()：每行像素占用的字节数；getHeight()：行数
                    return bitmap.getRowBytes() * bitmap.getHeight();
                } else if (value instanceof Serializable) {
                    // 计算 Serializable 对象大小（需对象实现 Serializable 接口）
                    try {
                        ByteArrayOutputStream bos = new ByteArrayOutputStream();
                        ObjectOutputStream oos = new ObjectOutputStream(bos);
                        oos.writeObject(value);
                        oos.close();
                        return bos.toByteArray().length;
                    } catch (IOException e) {
                        e.printStackTrace();
                        return 1024; // 兜底：按 1KB 估算
                    }
                } else {
                    // 其他类型：默认按 1KB 估算（可根据业务扩展）
                    return 1024;
                }
            }

            /**
             * 可选重写：缓存项被移除时回调（如回收资源、日志记录）
             * @param evicted true：因容量不足被淘汰；false：主动调用 remove 移除
             * @param key 缓存键
             * @param oldValue 被移除的缓存值
             * @param newValue 新缓存值（若为 put 导致移除则不为 null）
             */
            @Override
            protected void entryRemoved(boolean evicted, String key, Object oldValue, Object newValue) {
                super.entryRemoved(evicted, key, oldValue, newValue);
                // 示例 1：回收 Bitmap 资源（避免内存泄漏）
                if (oldValue instanceof Bitmap && !((Bitmap) oldValue).isRecycled()) {
                    ((Bitmap) oldValue).recycle();
                }
                // 示例 2：日志记录（监控缓存淘汰情况）
                if (evicted) {
                    Log.d("LruCache", "缓存淘汰：key=" + key + "，原因：容量不足");
                    // 通知UI层缓存被淘汰
                        notifyCacheChanged(key);
                }
            }
        };
    }

    // 单例获取方法（双重校验锁，线程安全）
    public static MemoryCacheManager getInstance() {
        if (INSTANCE == null) {
            synchronized (MemoryCacheManager.class) {
                if (INSTANCE == null) {
                    INSTANCE = new MemoryCacheManager();
                }
            }
        }
        return INSTANCE;
    }

    // 封装：存储 String
    public void putString(String key, String value) {
        mLruCache.put(key, value);
        notifyCacheChanged(key);
    }

    // 封装：读取 String（默认值为空字符串）
    public String getString(String key) {
        return getString(key, "");
    }

    public String getString(String key, String defaultValue) {
        Object value = mLruCache.get(key);
        return value instanceof String ? (String) value : defaultValue;
    }

    // 封装：存储 Bitmap
    public void putBitmap(String key, Bitmap bitmap) {
        if (bitmap != null && !bitmap.isRecycled()) {
            mLruCache.put(key, bitmap);
            notifyCacheChanged(key);
        }
    }

    // 封装：读取 Bitmap
    public Bitmap getBitmap(String key) {
        Object value = mLruCache.get(key);
        return (value instanceof Bitmap && !((Bitmap) value).isRecycled()) ? (Bitmap) value : null;
    }

    // 封装：存储 Serializable 对象
    public void putSerializable(String key, Serializable value) {
        mLruCache.put(key, value);
        notifyCacheChanged(key);
    }

    /**
     * 仅更新，不通知UI层
     * @param key
     * @param value
     */
    public void putSerializableNoNotice(String key, Serializable value) {
        if (value == null) {
            mLruCache.remove(key);
            return;
        }
        mLruCache.put(key, value);
    }
    // 封装：读取 Serializable 对象
    public <T extends Serializable> T getSerializable(String key) {
        Object value = mLruCache.get(key);
        return (value instanceof Serializable) ? (T) value : null;
    }

    // 封装：移除缓存
    public void remove(String key) {
        mLruCache.remove(key);
        notifyCacheChanged(key);
    }

    // 封装：清空所有缓存
    public void clearAll() {
        mLruCache.evictAll();
        mUiHandler.post(() -> {
            listenerMap.forEach((key, listeners) -> {
                if (listeners == null || listeners.isEmpty()) {
                    return;
                }
                try {
                    listeners.forEach(listener -> listener.onCacheChanged(key));
                }catch (Exception exception){
                    Log.e(TAG, "Error occurred while notifying cache changed: " + exception.getMessage());
                }

            });
        });
    }
    /**
     * 通知所有监听器缓存变化
     */
    private void notifyCacheChanged(final String key) {
        List<OnCacheChangedListener> listeners = listenerMap.get(key);
        if (listeners == null|| listeners.isEmpty()){
            return;
        }
        mUiHandler.post(() -> {
                for (OnCacheChangedListener listener : listeners) {
                    if (listener == null) {
                        continue;
                    }
                    try{
                        listener.onCacheChanged(key);
                    }catch (Exception exception){
                        Log.e(TAG, "Error occurred while notifying cache changed: " + exception.getMessage());
                    }

                }
        });
    }

    /**
     * 移除监听器
     * @param key
     * @param listener
     */
    public void removeListener(String key, OnCacheChangedListener listener) {
        List<OnCacheChangedListener> listeners = listenerMap.get(key);
        if (listeners == null || listeners.isEmpty()) {
            return;
        }
        listeners.remove(listener);
        if (listeners.isEmpty()) {
            listenerMap.remove(key);
        }
    }

    /**
     * 移除所有的监听器
     */
    public void removeAllListener() {
        listenerMap.clear();
    }

    /**
     * 添加监听器
     * @param key
     * @param listener
     */
    public void addListener(String key, OnCacheChangedListener listener) {
        CopyOnWriteArrayList<OnCacheChangedListener> listeners = listenerMap.get(key);
        if (listeners == null) {
            listeners = new CopyOnWriteArrayList<>();
        }
        listeners.add(listener);
        listenerMap.put(key, listeners);
    }
    /**
     * 缓存数据变化监听器
     */
    public interface OnCacheChangedListener {
        /**
         * 当缓存数据发生变化时回调
         * @param key 发生变化的缓存键
         */
        void onCacheChanged(String key);
    }
}