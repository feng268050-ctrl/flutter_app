package com.lasercyber.lws.ui.common.upgrade;

import android.util.Log;

import com.alibaba.excel.EasyExcel;
import com.alibaba.excel.context.AnalysisContext;
import com.alibaba.excel.event.AnalysisEventListener;
import com.alibaba.excel.exception.ExcelDataConvertException;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;

public class EasyExcelUtil {

    private static final String TAG = "EasyExcelUtil";

    /**
     * Parses a process-library .xlsx using the OTA import profile ({@link ProcessLibImportProfile#OTA_PROCESS_LIB}):
     * required headers 参数名称, 工艺类型, 数据类型; canonical column bindings in {@link ProcessLibColumn}.
     * <p>
     * Extension: call {@link #proFileConvert(File, ProcessLibImportProfile)} with a custom profile to adjust
     * required headers or supply {@link ProcessLibImportProfile#aliasToCanonical()} for non-Chinese header rows.
     *
     * @param file xlsx file on disk
     * @return one {@link ProcessParametersData} per data row (row 0 is headers only)
     */
    public static List<ProcessParametersData> proFileConvert(File file) {
        return proFileConvert(file, ProcessLibImportProfile.OTA_PROCESS_LIB);
    }

    /**
     * Same as {@link #proFileConvert(File)} but uses the given {@link ProcessLibImportProfile}
     * (required headers and optional header aliases).
     */
    public static List<ProcessParametersData> proFileConvert(File file, ProcessLibImportProfile profile) {
        if (file == null || !file.exists() || !file.isFile()) {
            throw new IllegalArgumentException("文件不存在或不是有效文件");
        }
        if (!file.getName().toLowerCase().endsWith(".xlsx")) {
            throw new IllegalArgumentException("文件不是.xlsx格式");
        }

        List<ProcessParametersData> resultList = new ArrayList<>();
        AtomicReference<Map<String, Integer>> headerToIndexRef = new AtomicReference<>();
        AtomicReference<RuntimeException> fatalRef = new AtomicReference<>();

        EasyExcel.read(file, new AnalysisEventListener<Object>() {
            @Override
            public void invokeHeadMap(Map<Integer, String> headMap, AnalysisContext context) {
                if (fatalRef.get() != null) {
                    return;
                }
                try {
                    Map<String, Integer> headerToIndex =
                            ProcessLibHeaderResolver.resolveHeaderRow(headMap, profile);
                    Log.i(TAG, "Process lib import header columns at row "
                            + context.readRowHolder().getRowIndex() + ": " + headerToIndex.keySet());
                    profile.validateRequiredHeaders(headerToIndex);
                    headerToIndexRef.set(headerToIndex);
                } catch (RuntimeException e) {
                    Log.e(TAG, "Invalid header row; columns seen: " + headMap.values(), e);
                    fatalRef.set(e);
                }
            }

            @Override
            public void invoke(Object data, AnalysisContext context) {
                if (fatalRef.get() != null) {
                    return;
                }
                if (!(data instanceof Map)) {
                    return;
                }
                @SuppressWarnings("unchecked")
                Map<?, ?> rowData = (Map<?, ?>) data;
                int rowIndex = context.readRowHolder().getRowIndex();

                if (headerToIndexRef.get() == null) {
                    fatalRef.set(new IllegalStateException(
                            "Header not resolved before data row at index " + rowIndex));
                    return;
                }

                try {
                    resultList.add(ProcessLibRowMapper.mapDataRow(rowData, headerToIndexRef.get()));
                } catch (Exception e) {
                    Log.e(TAG, "Row " + rowIndex + " parse failed: " + e.getMessage());
                }
            }

            @Override
            public void doAfterAllAnalysed(AnalysisContext context) {
                Log.d(TAG, "解析完成，共解析" + resultList.size() + "行有效数据");
            }

            @Override
            public void onException(Exception exception, AnalysisContext context) {
                Log.e(TAG, "解析异常：" + exception.getMessage());
                if (exception instanceof ExcelDataConvertException) {
                    ExcelDataConvertException convertException = (ExcelDataConvertException) exception;
                    Log.e(TAG, "第" + convertException.getRowIndex() + "行第"
                            + convertException.getColumnIndex() + "列数据转换失败");
                }
            }
        }).sheet().doRead();

        RuntimeException fatal = fatalRef.get();
        if (fatal != null) {
            throw fatal;
        }
        if (headerToIndexRef.get() == null) {
            throw new IllegalArgumentException("工艺库表格缺少表头行");
        }

        return resultList;
    }
}
