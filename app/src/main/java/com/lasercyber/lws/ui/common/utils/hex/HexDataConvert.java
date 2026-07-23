package com.lasercyber.lws.ui.common.utils.hex;

import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.annotation.HexData;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.enums.HexDataBiteType;
import com.lasercyber.lws.ui.common.enums.HexDataFiledType;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

import cn.hutool.core.convert.Convert;

/**
 * 十六进制与十进制的转换
 */
public class HexDataConvert {
    private static final String TAG = LogTAGConstant.HexConvert;

    /**
     * 将十进制数据转为16进制
     * @param hex
     * @return
     */
    public static String convertToHexData(Hex hex) {
        List<HexDataContent> filedList = createFiledList(hex);
        return fileListConvertToHexData(filedList);
    }

    /**
     * 将字段列表转为十六进制数据
     * @param fields
     * @return
     */
    public static String fileListConvertToHexData(List<HexDataContent> fields) {
        StringBuilder hex = new StringBuilder();
        if (fields==null||fields.isEmpty()){
            return hex.toString();
        }
        for (HexDataContent hexDataContent : fields) {
            String hexData = convertFieldDataToHex(hexDataContent);
            hex.append(hexData);
        }
        return hex.toString();
    }

    private static String convertFieldDataToHex(HexDataContent hexDataContent) {
        HexData annotation = hexDataContent.getHexData();
        Field declaredField = hexDataContent.getField();
        Object data = hexDataContent.getData();
        HexDataBiteType hexDataBiteType = getHexDataBiteType(annotation, declaredField);
        if (hexDataContent.hasChildField()) {
            StringBuilder arr = new StringBuilder();
            int size=data==null?0:1;
            if (HexDataFiledType.ARRAY_FILED==annotation.filedType()||
                    HexDataFiledType.OBJECT_FILED==annotation.filedType()){
                //noinspection rawtypes
                if (data instanceof Collection dataCollection){
                    // 当前为数组
                    size=dataCollection.size();
                    for (Object itemData : dataCollection) {
                        convertChildFieldToHex(hexDataContent.getChildren(), itemData, arr);
                    }
                }else {
                    // 当前为对象字段
                    convertChildFieldToHex(hexDataContent.getChildren(), data, arr);
                }
            }
            String arrLength = SendPointerUpdate.convertToHexData(hexDataBiteType, annotation.size(), size);
            return arrLength+ arr;
        }
        return SendPointerUpdate.convertToHexData(hexDataBiteType, annotation.size(), data);
    }

    /**
     * 转换子字段
     * @param children
     * @param itemData
     * @param arr
     */
    private static void convertChildFieldToHex(List<HexDataContent> children, Object itemData, StringBuilder arr) {
        if (itemData==null){
            return;
        }
        for (HexDataContent child : children) {
            try {
                child.setData(child.getField().get(itemData));
            } catch (IllegalAccessException e) {
                Log.e(TAG, "convertFieldDataToHex: 设置新值异常", e);
            }
            String childItemData = convertFieldDataToHex(child);
            arr.append(childItemData);
        }
    }

    /**
     * 获取十六进制数据类型
     * @param annotation
     * @param declaredField
     * @return
     */
    private static HexDataBiteType getHexDataBiteType(HexData annotation, Field declaredField) {
        HexDataBiteType hexDataBiteType;
        if (annotation.biteType()== HexDataBiteType.DEFAULT_BITE_TYPE){
            hexDataBiteType=HexDataBiteType.fileTypeToHexDataBiteType(declaredField.getType().getName());
        }else {
            hexDataBiteType= annotation.biteType();
        }
        return hexDataBiteType;
    }

    /**
     * 生成字段列表
     * @param hex
     * @return
     */
    public static List<HexDataContent> createFiledList(Hex hex){
        Field[] declaredFields = hex.getClass().getDeclaredFields();
        ArrayList<HexDataContent> hexDataContents = new ArrayList<>();
        for (Field declaredField : declaredFields) {
            HexDataContent hexDataContent = getFiledContent(hex, declaredField);
            if (hexDataContent == null) continue;
            hexDataContents.add(hexDataContent);
        }
        // 排序
        return hexDataContents.stream().sorted(Comparator.comparing((item) -> item.getHexData().order())).collect(Collectors.toList());
    }

    private static @Nullable HexDataContent getFiledContent(Object hex, Field declaredField) {
        if (!declaredField.isAnnotationPresent(HexData.class)) {
            return null;
        }
        HexData annotation = declaredField.getAnnotation(HexData.class);
        if (annotation==null){
            return null;
        }
        declaredField.setAccessible(true);
        // 获取declaredField中的属性值
        Object data;
        try {
            data = declaredField.get(hex);
        } catch (IllegalAccessException e) {
            Log.e(TAG, "createFiledList: 转换数据为16进制时异常，无法获取对象的字段数据",e );
            return null;
        }
        HexDataContent hexDataContent = HexDataContent.create(declaredField, annotation,data);
        if (annotation.filedType()== HexDataFiledType.ARRAY_FILED||
                annotation.filedType()== HexDataFiledType.OBJECT_FILED){
            // 当前为数组字段或对象字段
            Class<? extends Hex> childedClazz = annotation.childClazz();
            Field[] arrayChildFields = childedClazz.getDeclaredFields();
            Object first=data;
            if (data instanceof Collection<?> listData){
                // 获取第一个，兼容数组
                first= listData.iterator().next();
            }
            for (Field arrayChildField : arrayChildFields) {
                HexDataContent childFiled = getFiledContent(first, arrayChildField);
                if (childFiled==null){
                    continue;
                }
                hexDataContent.pushChild(childFiled);
            }
            if (hexDataContent.hasChildField()) {
                // 排序
                hexDataContent.getChildren().sort(Comparator.comparing((item) -> item.getHexData().order()));
            }
        }
        return hexDataContent;
    }

    /**
     * 将十六进制转为十进制对象
     * @param hexData
     * @param t
     * @return
     * @param <T>
     */
    public static <T extends Hex> T convertToObject(String hexData, T t) {
        List<HexDataContent> filedList = createFiledList(t);
       return fileListConvertToObject(hexData, filedList,t);
    }

    /**
     * 将字段列表转为对象
     * @param hexDataStr
     * @param fields
     * @param t
     * @return
     * @param <T>
     */
    public static <T extends Hex> T fileListConvertToObject(String hexDataStr, List<HexDataContent>  fields,T t)  {
        PointerUpdate pointerUpdate = new PointerUpdate(hexDataStr);
        for (HexDataContent dataContent : fields) {
            convertContentToObject(t, dataContent, pointerUpdate);
        }
        return t;
    }

    /**
     * 转换内容
     * @param t
     * @param dataContent
     * @param pointerUpdate
     * @param <T>
     */
    private static <T extends Hex> void convertContentToObject(T t, HexDataContent dataContent, PointerUpdate pointerUpdate) {
        HexData hexData = dataContent.getHexData();
        Field field = dataContent.getField();
        HexDataBiteType hexDataBiteType = getHexDataBiteType(hexData, field);
        if (dataContent.hasChildField()){
            // 长度字段
            Object length = ProtocolHexToDecimal.convertToObject(pointerUpdate, hexDataBiteType, hexData.size());
            int lengthData = Convert.toInt(length);
            Class<? extends Hex> childedClazz = hexData.childClazz();
            if (hexData.filedType()== HexDataFiledType.ARRAY_FILED){
                // 当前为数组
                ArrayList<Hex> hexes = new ArrayList<>(lengthData);
                for (int i = 0; i < lengthData; i++) {
                    Hex childHex = getHexInstance(childedClazz);
                    if (childHex==null){
                        continue;
                    }
                    for (HexDataContent child : dataContent.getChildren()) {
                        convertContentToObject(childHex, child, pointerUpdate);
                    }
                    hexes.add(childHex);
                }
                setObjectData(t, field, hexes);
            }else if (hexData.filedType()== HexDataFiledType.OBJECT_FILED){
                // 当前为对象
                Hex childHex = getHexInstance(childedClazz);
                if (childHex==null){
                    return;
                }
                for (HexDataContent child : dataContent.getChildren()) {
                    convertContentToObject(childHex, child, pointerUpdate);
                }
                setObjectData(t, field, childHex);
            }
            return;
        }
        Object data = ProtocolHexToDecimal.convertToObject(pointerUpdate, hexDataBiteType, hexData.size());
        setObjectData(t, field, data);
    }

    /**
     * 往对象中set数据
     * @param t
     * @param field
     * @param childHex
     * @param <T>
     */
    private static <T extends Hex> void setObjectData(T t, Field field, Object childHex) {
        try {
            field.set(t, childHex);
        } catch (IllegalAccessException e) {
            Log.e(TAG, "fileListConvertToObject: 转换为10进制对象时，设置数据异常",e );
        }
    }

    /**
     * 获取对象实例
     * @param childedClazz
     * @return
     */
    private static  Hex getHexInstance(Class<? extends Hex> childedClazz) {
        Hex childHex = null;
        try {
            childHex = childedClazz.newInstance();
        } catch (IllegalAccessException | InstantiationException e) {
            Log.d(TAG, "getHexInstance: 生成对象实例异常",e);
        }
        return childHex;
    }
}
