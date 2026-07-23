package com.lasercyber.lws.ui.common.utils;

import com.lasercyber.lws.ui.common.constant.CryptoConstants;

import java.nio.charset.StandardCharsets;
import java.security.InvalidAlgorithmParameterException;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;

import javax.crypto.BadPaddingException;
import javax.crypto.Cipher;
import javax.crypto.IllegalBlockSizeException;
import javax.crypto.NoSuchPaddingException;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

import cn.hutool.crypto.digest.DigestUtil;
import lombok.Data;

/**
 * 加解密工具类（修复解密模式问题）
 *
 * @author 里子不会Java
 * @version V1.0
 * @since 2026-01-21 15:06
 */
@Data
public class CipherUtils {
    private final String key; // 保存密钥，用于解密时初始化Cipher
    private Cipher encryptCipher; // 加密专用Cipher
    private Cipher decryptCipher; // 解密专用Cipher

    public CipherUtils(String key) {
        this.key = key;
        try {
            // 初始化加密Cipher
            initEncryptCipher();
            // 初始化解密Cipher
            initDecryptCipher();
        } catch (NoSuchAlgorithmException | NoSuchPaddingException | InvalidKeyException |
                 InvalidAlgorithmParameterException e) {
            throw new RuntimeException("Cipher初始化失败", e);
        }
    }

    /**
     * 初始化加密模式的Cipher
     */
    private void initEncryptCipher() throws NoSuchAlgorithmException, NoSuchPaddingException,
            InvalidKeyException, InvalidAlgorithmParameterException {
        SecretKeySpec secretKey = new SecretKeySpec(
                key.getBytes(StandardCharsets.UTF_8),
                CryptoConstants.ALGORITHM_DEVICE
        );
        IvParameterSpec iv = getIvParameterSpec();

        encryptCipher = Cipher.getInstance(CryptoConstants.TRANSFORMATION_DEVICE);
        encryptCipher.init(Cipher.ENCRYPT_MODE, secretKey, iv);
    }

    /**
     * 初始化解密模式的Cipher
     */
    private void initDecryptCipher() throws NoSuchAlgorithmException, NoSuchPaddingException,
            InvalidKeyException, InvalidAlgorithmParameterException {
        SecretKeySpec secretKey = new SecretKeySpec(
                key.getBytes(StandardCharsets.UTF_8),
                CryptoConstants.ALGORITHM_DEVICE
        );
        IvParameterSpec iv = getIvParameterSpec();

        decryptCipher = Cipher.getInstance(CryptoConstants.TRANSFORMATION_DEVICE);
        decryptCipher.init(Cipher.DECRYPT_MODE, secretKey, iv); // 关键：初始化为解密模式
    }

    /**
     * 统一生成IV参数（确保加密/解密IV完全一致）
     */
    private IvParameterSpec getIvParameterSpec() {
        return new IvParameterSpec(
                DigestUtil.md5Hex(key).substring(0, 16).getBytes(StandardCharsets.UTF_8)
        );
    }

    /**
     * 加密
     *
     * @param data 明文
     * @return 加密后Base64编码的字符串
     */
    public String encrypt(String data) {
        try {
            byte[] encryptBytes = encryptCipher.doFinal(data.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(encryptBytes);
        } catch (IllegalBlockSizeException | BadPaddingException e) {
            throw new RuntimeException("加密失败", e);
        }
    }

    /**
     * 解密
     *
     * @param cipherText 加密后的Base64字符串
     * @return 明文
     */
    public String decrypt(String cipherText) {
        try {
            // 1. Base64解码
            byte[] cipherBytes = Base64.getDecoder().decode(cipherText);
            // 2. 解密（使用解密模式的Cipher）
            byte[] plainBytes = decryptCipher.doFinal(cipherBytes);
            // 3. 转字符串
            return new String(plainBytes, StandardCharsets.UTF_8);
        } catch (IllegalBlockSizeException | BadPaddingException e) {
            throw new RuntimeException("解密失败（密钥错误/密文损坏/模式不匹配）", e);
        }
    }
}
