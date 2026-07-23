package com.lasercyber.lws.ui.common.utils.qrcode;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.util.Log;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.util.HashMap;
import java.util.Map;

public class QRCodeGenerator {
    private static final String TAG = LogTAGConstant.QRCodeUtils;

    /**
     * 生成基础二维码
     *
     * @param content 二维码内容（如文本、URL、JSON 等）
     * @param width   二维码宽度（像素）
     * @param height  二维码高度（像素）
     * @return 二维码 Bitmap
     */
    public static Bitmap generateQRCode(String content, int width, int height) {
        try {
            // 1. 检查内容合法性
            if (content == null || content.isEmpty()) {
                return null;
            }
            // 2. 初始化 QRCodeWriter
            QRCodeWriter qrCodeWriter = new QRCodeWriter();
            // 关键：设置二维码编码参数，强制指定 UTF-8 字符集
            Map<EncodeHintType, Object> hints = new HashMap<>();
            hints.put(EncodeHintType.CHARACTER_SET, "UTF-8"); // 解决中文乱码的核心配置
//            hints.put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.H); // 高容错（可选，避免遮挡）
            hints.put(EncodeHintType.MARGIN, 1); // 减少二维码边距（可选）
            // 3. 生成 BitMatrix（二维码的矩阵数据）
            BitMatrix bitMatrix = qrCodeWriter.encode(
                    content,
                    BarcodeFormat.QR_CODE,
                    width,
                    height,
                    hints
            );

            // 4. 将 BitMatrix 转换为 Bitmap
            int[] pixels = new int[width * height];
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    // 设置二维码颜色（黑码白边，可自定义）
                    pixels[y * width + x] = bitMatrix.get(x, y) ? 0xFF000000 : 0xFFFFFFFF;
                }
            }
            // 5. 创建 Bitmap 并返回
            Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
            bitmap.setPixels(pixels, 0, width, 0, 0, width, height);
            return bitmap;

        } catch (WriterException e) {
            // 编码失败（如内容过长）
            Log.e(TAG, "generateQRCode: 创建二维码失败",e );
            return null;
        }
    }

    /**
     * 生成带 Logo 和自定义颜色的二维码
     *
     * @param content   内容
     * @param width     宽度
     * @param height    高度
     * @param logo      中心 Logo（可选）
     * @param codeColor 二维码颜色（默认黑色）
     * @param bgColor   背景颜色（默认白色）
     * @return 带样式的二维码
     */
    public static Bitmap generateStyledQRCode(String content, int width, int height,
                                              Bitmap logo, int codeColor, int bgColor) {
        // 1. 生成基础二维码
        Bitmap baseQRCode = generateQRCode(content, width, height);
        if (baseQRCode == null) {
            return null;
        }

        // 2. 自定义颜色（重新绘制二维码）
        Bitmap styledQRCode = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(styledQRCode);
        Paint paint = new Paint();
        paint.setAntiAlias(true);

        // 绘制背景
        canvas.drawColor(bgColor);

        // 重新绘制二维码颜色
        int[] pixels = new int[width * height];
        baseQRCode.getPixels(pixels, 0, width, 0, 0, width, height);
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                if (pixels[y * width + x] == 0xFF000000) { // 原黑色码点
                    pixels[y * width + x] = codeColor; // 替换为自定义颜色
                }
            }
        }
        styledQRCode.setPixels(pixels, 0, width, 0, 0, width, height);

        // 3. 添加中心 Logo（若有）
        if (logo != null) {
            // 计算 Logo 尺寸（建议为二维码的 1/5 ~ 1/4，避免遮挡信息）
            int logoSize = Math.min(width, height) / 4;
            // 缩放 Logo 到合适尺寸
            Bitmap scaledLogo = Bitmap.createScaledBitmap(logo, logoSize, logoSize, true);
            // 计算 Logo 位置（居中）
            int logoX = (width - logoSize) / 2;
            int logoY = (height - logoSize) / 2;
            // 绘制 Logo
            canvas.drawBitmap(scaledLogo, logoX, logoY, paint);
        }

        return styledQRCode;
    }
}
