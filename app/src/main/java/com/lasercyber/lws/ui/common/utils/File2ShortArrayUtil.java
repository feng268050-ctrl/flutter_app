package com.lasercyber.lws.ui.common.utils;

import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;

/**
 * 高性能、高可靠性的文件转short[]工具类
 * 核心：使用NIO的FileChannel读取文件，直接拼接字节为short，减少内存拷贝
 */
public class File2ShortArrayUtil {
    private static final String TAG = LogTAGConstant.File2ShortArrayUtil;
    // 缓冲区大小：8KB（匹配磁盘块大小，兼顾小文件和大文件，可根据实际场景调整为16KB/32KB）
    private static final int BUFFER_SIZE = 8 * 1024;
    // 最大支持的文件大小：1MB（可根据需求调整，防止OOM）
    private static final long MAX_FILE_SIZE = 1 * 1024 * 1024;

    /**
     * 读取文件为字节数组
     * @param file
     * @return
     */
    public static byte[] readFileToByteArr(File file){
        // 步骤1：前置校验（高可靠性）
        if (file == null) {
            Log.e(TAG, "File is null");
            return null;
        }
        if (!file.exists()) {
            Log.e(TAG, "File not exists: " + file.getAbsolutePath());
            return null;
        }
        if (!file.isFile()) {
            Log.e(TAG, "Not a file: " + file.getAbsolutePath());
            return null;
        }
        long fileLength = file.length();
        if (fileLength == 0) {
            Log.w(TAG, "File is empty: " + file.getAbsolutePath());
            return new byte[0];
        }
        // 限制文件大小，防止OOM（高可靠性）
        if (fileLength > MAX_FILE_SIZE) {
            Log.e(TAG, "File too large: " + fileLength + " bytes, max support: " + MAX_FILE_SIZE + " bytes");
            return null;
        }
        // 若文件长度为奇数，忽略最后一个字节（或抛异常，此处选择忽略，可根据需求调整）
        long effectiveLength = fileLength % 2 == 0 ? fileLength : fileLength - 1;
        if (effectiveLength == 0) {
            Log.w(TAG, "File has only 1 byte, ignore it");
            return new byte[0];
        }

        // 步骤2：使用NIO读取文件（高性能）
        byte[] byteArray;
        try (FileInputStream fis = new FileInputStream(file);
             FileChannel channel = fis.getChannel()) {

            // 分配直接缓冲区（减少堆内存拷贝，高性能）
            ByteBuffer buffer = ByteBuffer.allocateDirect((int) effectiveLength);
            // 读取文件内容到缓冲区（确保读取完整）
            int bytesRead = channel.read(buffer);
            if (bytesRead != effectiveLength) {
                Log.e(TAG, "Read file incomplete: expected " + effectiveLength + " bytes, actual " + bytesRead + " bytes");
                return null;
            }
            // 翻转缓冲区，准备读取
            buffer.flip();
            // 转换为字节数组（若使用堆外缓冲区，此处是唯一的内存拷贝，不可避免）
            byteArray = new byte[(int) effectiveLength];
            buffer.get(byteArray);

        } catch (IOException e) {
            Log.e(TAG, "Read file failed: ", e);
            return null;
        }
        return byteArray;
    }
}