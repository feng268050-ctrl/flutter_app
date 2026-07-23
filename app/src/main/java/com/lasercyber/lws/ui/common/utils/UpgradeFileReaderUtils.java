package com.lasercyber.lws.ui.common.utils;

import android.os.Environment;
import android.util.Log;

import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.common.constant.FileConstant;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.File;
import java.io.FileInputStream;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;

/**
 * 升级文件读取工具。
 * <p>控制板固件 {@code .bin} 文件名约定（非 SemVer）：{@code LSW01H####S####.bin}，
 * {@code H} 与 {@code S} 之间四位为硬件版本，{@code S} 之后四位为软件版本（十进制）。
 * 例：{@code LSW01H1000S1012.bin} → 硬件 1000，软件 1012。</p>
 */
public class UpgradeFileReaderUtils {
    private static final String TAG = LogTAGConstant.UpgradeFileReaderUtils;

    private static final int FIRMWARE_HW_START = 6;
    private static final int FIRMWARE_HW_END = 10;
    private static final int FIRMWARE_SW_START = 11;
    private static final int FIRMWARE_SW_END = 15;

    /**
     * 获取upgrade目录（不存在则创建）
     */
    public static File getUpgradeDir(String filePath) {
//        File externalRoot = Utils.getApp().getExternalCacheDir();
        String externalRoot = Utils.getApp().getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS).getAbsolutePath();
        String upgradeRootPath = FileConstant.UPGRADE_ROOT_PATH;
        if (!StringUtils.isEmpty(filePath)) {
            if (!filePath.startsWith("/")) {
                upgradeRootPath += "/";
            }
            upgradeRootPath += filePath;
        }
        Log.d(TAG, "升级文件的目录:" + externalRoot + "/" + upgradeRootPath);
        File upgradeDir = new File(externalRoot, upgradeRootPath);
        // 若目录不存在，创建（需WRITE权限，Android 10+需兼容模式或MANAGE权限）
        if (!upgradeDir.exists()) {
            boolean isCreated = upgradeDir.mkdirs();
            if (!isCreated) {
                Log.e(TAG, "创建upgrade目录失败：" + upgradeDir.getAbsolutePath());
                return null;
            }
        }
        return upgradeDir;
    }

    /**
     * 读取文件数据为short数组
     * @param fileName
     * @return
     */
//    public static short[] readUpgradeFileToShortArray(String fileName){
//        File file = readFile(fileName);
//        return File2ShortArrayUtil.readFileToSignedShortArray(file);
//    }

    /**
     * 获取文件信息
     *
     * @param fileName
     * @return
     */
    public static File readFile(String fileName, String filePath) {
        // 1. 获取upgrade目录
        File upgradeDir = getUpgradeDir(filePath);
        if (upgradeDir == null) {
            return null;
        }
        // 2. 构建文件对象
        return new File(upgradeDir, fileName);
    }

    /**
     * 获取文件的硬件版本（{@code H} 与 {@code S} 之间连续四位十进制数字，见类注释约定）
     */
    public static Integer getFileHardwareVersion(String fileName) {
        if (StringUtils.isEmpty(fileName) || fileName.length() < FIRMWARE_HW_END) {
            return null;
        }
        try {
            return Integer.parseInt(fileName.substring(FIRMWARE_HW_START, FIRMWARE_HW_END));
        } catch (NumberFormatException e) {
            Log.w(TAG, "invalid firmware HW segment in fileName=" + fileName, e);
            return null;
        }
    }

    /**
     * 获取文件的软件版本（{@code S} 之后连续四位十进制数字，见类注释约定）
     */
    public static Integer getFileSoftwareVersion(String fileName) {
        if (StringUtils.isEmpty(fileName) || fileName.length() < FIRMWARE_SW_END) {
            return null;
        }
        try {
            return Integer.parseInt(fileName.substring(FIRMWARE_SW_START, FIRMWARE_SW_END));
        } catch (NumberFormatException e) {
            Log.w(TAG, "invalid firmware SW segment in fileName=" + fileName, e);
            return null;
        }
    }

    /**
     * 字符串分割法截取文件名
     *
     * @param url 目标URL
     * @return 文件名（无则返回空字符串）
     */
    public static String extractFileNameBySplit(String url) {
        if (url == null || url.isEmpty()) {
            return "";
        }
        // 找到最后一个 "/" 的索引
        int lastSlashIndex = url.lastIndexOf("/");
        // 若存在 "/"，且不是最后一个字符，则截取后面的字符串
        if (lastSlashIndex != -1 && lastSlashIndex < url.length() - 1) {
            return url.substring(lastSlashIndex + 1);
        }
        return "";
    }

    /**
     * 读取指定范围的数据
     *
     * @param file   文件对象
     * @param startPos  起始位置
     * @param length 读取长度
     * @return 读取的数据
     */
    public static byte[] readRangeBytes(File file, long startPos, int length) {
        if (length==0){
            return new byte[0];
        }
        try (FileInputStream fis = new FileInputStream(file);
             FileChannel channel = fis.getChannel()) {
            // 1. 创建ByteBuffer，容量为要读取的长度
            ByteBuffer buffer = ByteBuffer.allocate(length);
            // 2. 设置通道的读取起始位置
            channel.position(startPos);
            // 3. 读取字节到缓冲区（read方法返回实际读取的字节数）
            int bytesRead = channel.read(buffer);
            // 4. 切换缓冲区为读模式
            buffer.flip();
            // 5. 提取字节数组（考虑实际读取的字节数可能小于length，比如文件末尾）
            byte[] result = new byte[bytesRead];
            buffer.get(result);

            return result;
        }catch (Exception exception){
            Log.d(TAG, "读取指定范围的文件数据异常：",exception);
        }
        return null;
    }
}
