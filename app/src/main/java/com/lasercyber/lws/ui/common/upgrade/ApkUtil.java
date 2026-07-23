package com.lasercyber.lws.ui.common.upgrade;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInstaller;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
/*当前软件升级*/
public class ApkUtil {

    /**
     * 基于本地.apk文件实现APP在线升级安装
     * @param file 本地.apk安装包文件
     */
    public void UIUp(File file,Context context) {

        if (!(context instanceof Activity)) {
            Log.e("ApkUtil","上下文必须为Activity");
            return;
        }
        Activity activity = (Activity) context;

        // 1. 校验文件合法性
        if (!checkApkFileValid(file)) {
            Log.e("ApkUtil","APK文件无效（不存在/非APK格式）");
            return;
        }

        // 2. 检查并申请安装权限（安卓8.0+必须）
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            boolean hasInstallPermission = context.getPackageManager().canRequestPackageInstalls();
            if (!hasInstallPermission) {
                // 跳转到设置页面开启未知来源安装权限
                Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES);
                intent.setData(Uri.parse("package:" + context.getPackageName()));
                activity.startActivityForResult(intent, 1001); // 1001为请求码，可自定义
                return;
            }
        }

        // 3. 执行APK安装逻辑
        installApk(context, file);
    }

    /**
     * 校验APK文件合法性
     * @param file APK文件
     * @return 是否有效
     */
    private boolean checkApkFileValid(File file) {
        if (file == null || !file.exists() || !file.isFile()) {
            return false;
        }
        // 校验后缀为.apk
        String fileName = file.getName().toLowerCase();
        if (!fileName.endsWith(".apk")) {
            return false;
        }
        // 校验文件大小（避免空文件，可根据业务调整最小大小）
        if (file.length() < 1024 * 1024) { // 最小1MB
            return false;
        }
        return true;
    }

    /**
     * 执行APK安装（适配不同安卓版本）
     * @param context 上下文
     * @param apkFile APK文件
     */
    private void installApk(Context context, File apkFile) {
        try {
            Intent installIntent = new Intent(Intent.ACTION_VIEW);
            Uri apkUri;

            // 适配安卓7.0+文件访问权限
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // 通过FileProvider生成content://类型的Uri
                apkUri = FileProvider.getUriForFile(
                        context,
                        context.getPackageName() + ".fileprovider", // 与清单文件中authorities一致
                        apkFile
                );
                // 授予临时访问权限
                installIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            } else {
                // 安卓7.0以下直接使用file://Uri
                apkUri = Uri.fromFile(apkFile);
            }

            // 设置安装参数
            installIntent.setDataAndType(apkUri, "application/vnd.android.package-archive");
            installIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); // 新开任务栈

            // 启动系统安装器
            context.startActivity(installIntent);
        } catch (Exception e) {
            // 兼容安卓11+的包安装API（备用方案）
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                installApkByPackageInstaller(context, apkFile);
            } else {
                Log.e("ApkUtil", "APK安装失败：" + e.getMessage());
            }
        }
    }

    /**
     * 安卓11+备用安装方案（PackageInstaller API）
     * @param context 上下文
     * @param apkFile APK文件
     */
    private void installApkByPackageInstaller(Context context, File apkFile) {
        PackageInstaller packageInstaller = context.getPackageManager().getPackageInstaller();
        PackageInstaller.SessionParams params = new PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL
        );
        int sessionId = -1;

        try {
            // 创建安装会话
            sessionId = packageInstaller.createSession(params);
            PackageInstaller.Session session = packageInstaller.openSession(sessionId);

            // 将APK文件写入会话
            OutputStream outputStream = session.openWrite("apk_file", 0, apkFile.length());
            FileInputStream inputStream = new FileInputStream(apkFile);
            byte[] buffer = new byte[1024 * 1024]; // 1MB缓冲区
            int len;
            while ((len = inputStream.read(buffer)) != -1) {
                outputStream.write(buffer, 0, len);
            }
            session.fsync(outputStream);
            inputStream.close();
            outputStream.close();

            // 执行安装
            Intent intent = new Intent(context, context.getClass());
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            session.commit(pendingIntent.getIntentSender());
            session.close();

            Log.e("ApkUtil", "正在安装，请稍候..." );
        } catch (IOException e) {
            Log.e("ApkUtil", "PackageInstaller安装失败：" + e.getMessage());
            // 清理会话
            if (sessionId != -1) {
                packageInstaller.abandonSession(sessionId);
            }
        }
    }

}
