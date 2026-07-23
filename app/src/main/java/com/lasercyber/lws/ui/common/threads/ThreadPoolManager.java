package com.lasercyber.lws.ui.common.threads;

import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 线程池管理
 */
public class ThreadPoolManager {
    // 核心线程数（根据CPU核心数动态调整，避免资源浪费）
    private static final int CORE_POOL_SIZE = Runtime.getRuntime().availableProcessors() + 1;
    // 最大线程数
    private static final int MAX_POOL_SIZE = Runtime.getRuntime().availableProcessors() * 2 + 1;
    // 临时线程空闲超时时间（60秒）
    private static final long KEEP_ALIVE_TIME = 60L;
    // 任务队列（容量128，超过则触发拒绝策略）
    private static final int QUEUE_CAPACITY = 128;

    // 单例线程池
    private static volatile ThreadPoolExecutor sExecutor;

    public static ThreadPoolExecutor getExecutor() {
        if (sExecutor == null) {
            synchronized (ThreadPoolManager.class) {
                if (sExecutor == null) {
                    // 线程工厂（指定线程名，便于调试）
                    ThreadFactory threadFactory = new ThreadFactory() {
                        private final AtomicInteger mCount = new AtomicInteger(1);

                        @Override
                        public Thread newThread(Runnable r) {
                            Thread thread = new Thread(r, "mj-laser-thread-" + mCount.getAndIncrement());
                            // 设置为守护线程（进程结束时自动销毁）
                            thread.setDaemon(true);
                            return thread;
                        }
                    };

                    // 初始化线程池
                    sExecutor = new ThreadPoolExecutor(
                            CORE_POOL_SIZE,
                            MAX_POOL_SIZE,
                            KEEP_ALIVE_TIME,
                            TimeUnit.SECONDS,
                            new LinkedBlockingQueue<>(QUEUE_CAPACITY),
                            threadFactory,
                            // 拒绝策略：当任务满时，由提交任务的线程执行（避免任务丢失）
                            new ThreadPoolExecutor.CallerRunsPolicy()
                    );
                }
            }
        }
        return sExecutor;
    }
}
