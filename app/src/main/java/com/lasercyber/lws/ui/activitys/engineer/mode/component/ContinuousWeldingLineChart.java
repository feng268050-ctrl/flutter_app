package com.lasercyber.lws.ui.activitys.engineer.mode.component;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.os.Handler;
import android.os.Looper;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import com.blankj.utilcode.util.ColorUtils;
import com.blankj.utilcode.util.SizeUtils;
import com.blankj.utilcode.util.Utils;
import com.github.mikephil.charting.charts.LineChart;
import com.github.mikephil.charting.components.XAxis;
import com.github.mikephil.charting.components.YAxis;
import com.github.mikephil.charting.data.Entry;
import com.github.mikephil.charting.data.LineData;
import com.github.mikephil.charting.data.LineDataSet;
import com.github.mikephil.charting.formatter.ValueFormatter;
import com.github.mikephil.charting.interfaces.datasets.ILineDataSet;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;

import java.util.ArrayList;
import java.util.List;

public class ContinuousWeldingLineChart implements WeldingChart{
    private Context context;
    private LineChart lineChart;
    private float t1Y=0f;
    private float t2Y=0f;
    private float t3Y=0f;
    private float t4Y=0f;

    private float t1X=0f;
    private float t2X=0f;
    private float t3X=0f;
    private float t4X=0f;
    private float t5X=0f;
    private final Handler handler=new android.os.Handler(Looper.getMainLooper());
    private Runnable task;

    public ContinuousWeldingLineChart(Context context) {
        this.context = context;
        // 2. 创建 LineChart 对象
        lineChart = new LineChart(context);
        lineChart.setLayoutParams(new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    }

    /**
     * 初始化图表
     */
    @Override
    public void initChart() {
        // 关闭描述文字
        lineChart.getDescription().setEnabled(false);
        // 关闭图例
        lineChart.getLegend().setEnabled(false);
        // 关闭缩放
        lineChart.setScaleEnabled(false);
        // 关闭拖拽
        lineChart.setDragEnabled(false);
        // 关闭网格线（可选）
        lineChart.getXAxis().setDrawGridLines(false);
        lineChart.getAxisLeft().setDrawGridLines(false);
        lineChart.getAxisRight().setEnabled(false); // 隐藏右侧Y轴
        // 1. 左右间距（影响X轴两侧）
        lineChart.setExtraLeftOffset(SizeUtils.dp2px(10));   // 左侧额外偏移
        lineChart.setExtraRightOffset(SizeUtils.dp2px(10));  // 右侧额外偏移
        // 2. 上下间距（影响Y轴两侧）
        lineChart.setExtraTopOffset(SizeUtils.dp2px(30));     // 顶部额外偏移
//        lineChart.setExtraBottomOffset(SizeUtils.dp2px(21)); // 底部额外偏移

        // X轴配置
        XAxis xAxis = lineChart.getXAxis();
        xAxis.setPosition(XAxis.XAxisPosition.BOTTOM);
        xAxis.setTextColor(Color.WHITE);
        // 设置X轴标签（对应T1-T4）
//        String[] xAxisTextArr = {"T1", "T2","", "T3", "T4"};
//        xAxis.setValueFormatter(new IndexAxisValueFormatter(xAxisTextArr));
//        xAxis.setCenterAxisLabels(true); // 标签居中对齐x轴的刻度线（数据点）
//        xAxis.setLabelCount(xAxisTextArr.length);

        // 精确匹配X轴数据范围，避免左右间隙
        xAxis.setAxisMinimum(0f);
        xAxis.setTextSize(24);
        // 4. 设置X轴标签（对应T1-T4），强制显示4个标签并均匀分布

        // Y轴配置（左侧）
        YAxis yAxis = lineChart.getAxisLeft();
        yAxis.setTextColor(Color.WHITE);
        yAxis.setAxisMinimum(0f); // Y轴从0开始
//        yAxis.setAxisMaximum(1.5f); // 适当的最大值，避免顶部挤压
        // 关闭Y轴自动计算的上下padding，确保图形紧贴X轴
        yAxis.setSpaceBottom(0f);
        yAxis.setSpaceTop(0f);
        yAxis.setTextSize(24);
//        yAxis.setGranularity(0.2f); // 网格线间隔

        // 调整视口偏移：减小底部偏移，确保图形紧贴X轴
//        float left = SizeUtils.dp2px(5f);
//        float top = SizeUtils.dp2px(11.5f);
//        float right = SizeUtils.dp2px(7f);
//        float bottom = SizeUtils.dp2px(5f); // 大幅减小底部偏移，避免图形与X轴的间隙
//        lineChart.setViewPortOffsets(left, top, right, bottom);
        this.task= this::renderData;
        handler.postDelayed(task,100);
    }

    /**
     * 初始化数据
     * @param processParametersData
     */
    @Override
    public void initData(ProcessParametersData processParametersData, Double startPower, Double endPower) {
        if (processParametersData==null){
            return;
        }
        if (task!=null){
            handler.removeCallbacks(task);
        }
//        this.t1Y=processParametersData.getCloseAirDelay()==null?0:processParametersData.getCloseAirDelay();
//        this.t2Y=processParametersData.getPowerRampUp()==null?0:processParametersData.getPowerRampUp();
//        this.t3Y=processParametersData.getPowerRampDown()==null?0:processParametersData.getPowerRampDown();
//        this.t4Y=processParametersData.getCloseAirDelay()==null?0:processParametersData.getCloseAirDelay();
        t1Y=startPower.floatValue();
        t4Y=endPower.floatValue();
        t2Y=processParametersData.getLaserPower()==null?0:processParametersData.getLaserPower();
        t3Y=processParametersData.getLaserPower()==null?0:processParametersData.getLaserPower();

        t1X=processParametersData.getBlowDelay()==null?0:processParametersData.getBlowDelay();
        t2X=processParametersData.getPowerRampUp()==null?0:processParametersData.getPowerRampUp();
        // 计算每一个间隔
        t3X=(t1X*2+t2X*2)/4;
        t2X+=t1X;
        t3X+=t2X;
        t4X=processParametersData.getPowerRampDown()==null?0:processParametersData.getPowerRampDown();
        t4X+=t3X;
        t5X=processParametersData.getCloseAirDelay()==null?0:processParametersData.getCloseAirDelay();
        t5X+=t4X;

        renderData();
    }

    private void renderData() {
        if (lineChart==null){
            return;
        }
        XAxis xAxis = lineChart.getXAxis();
        xAxis.setAxisMaximum(t5X+3);
        xAxis.setValueFormatter(new ValueFormatter() {
            @Override
            public String getFormattedValue(float value) {
                return "";
            }
        });

        YAxis yAxis = lineChart.getAxisLeft();
        yAxis.setAxisMaximum(Math.max(t1Y,t2Y)+2);
        // 分段填充数据集列表（存储所有填充区域）
        List<ILineDataSet> allDataSets = new ArrayList<>();
        // 1. 基础折线数据（统一折线，6个点：0-5）
        initLine(allDataSets);
        // 分区填充
        initPartitionFill(allDataSets);

        // 9. 生成LineData并设置到图表
        LineData lineData = new LineData(allDataSets);
        lineChart.setData(lineData);
        lineChart.invalidate(); // 刷新图表
    }

    private void initPartitionFill(List<ILineDataSet> allDataSets) {
        Drawable gradientDrawableBlue = ContextCompat.getDrawable(Utils.getApp(), R.drawable.line_chart_gradient_blue);
        Drawable gradientDrawableOrange = ContextCompat.getDrawable(Utils.getApp(), R.drawable.line_chart_gradient_orange);
        // 4. 分段1：低功率区域（X=0-1，蓝色填充）
        List<Entry> lowPower1Entries = new ArrayList<>();
        lowPower1Entries.add(new Entry(0f, t1Y)); // 左上
        lowPower1Entries.add(new Entry(t1X, t1Y)); // 右上
        lowPower1Entries.add(new Entry(t1X, 0f));   // 右下（Y=0，严格闭合）
        lowPower1Entries.add(new Entry(0f, 0f));   // 左下（Y=0，严格闭合）
        LineDataSet lowPower1Set = createFilledSegment(lowPower1Entries, gradientDrawableBlue); // 蓝色
        allDataSets.add(lowPower1Set);

        // 5. 分段2：上升区域（X=1-2，橙色填充）
        List<Entry> risingEntries = new ArrayList<>();
        risingEntries.add(new Entry(t1X, t1Y)); // 左上
        risingEntries.add(new Entry(t2X, t2Y));   // 右上
        risingEntries.add(new Entry(t2X, 0f));   // 右下（Y=0，严格闭合）
        risingEntries.add(new Entry(t1X, 0f));   // 左下（Y=0，严格闭合）
        LineDataSet risingSet = createFilledSegment(risingEntries, gradientDrawableOrange); // 橙色
        allDataSets.add(risingSet);

        // 6. 分段3：高功率区域（X=2-3，红色填充）
        List<Entry> highPowerEntries = new ArrayList<>();
        highPowerEntries.add(new Entry(t2X, t2Y));   // 左上
        highPowerEntries.add(new Entry(t3X, t3Y));   // 右上
        highPowerEntries.add(new Entry(t3X, 0f));   // 右下（Y=0，严格闭合）
        highPowerEntries.add(new Entry(t2X, 0f));   // 左下（Y=0，严格闭合）
        LineDataSet highPowerSet = createFilledSegment(highPowerEntries, gradientDrawableOrange); // 红色
        allDataSets.add(highPowerSet);

        // 7. 分段4：下降区域（X=3-4，黄色填充）
        List<Entry> fallingEntries = new ArrayList<>();
        fallingEntries.add(new Entry(t3X, t3Y));   // 左上
        fallingEntries.add(new Entry(t4X, t4Y)); // 右上
        fallingEntries.add(new Entry(t4X, 0f));   // 右下（Y=0，严格闭合）
        fallingEntries.add(new Entry(t3X, 0f));   // 左下（Y=0，严格闭合）
        LineDataSet fallingSet = createFilledSegment(fallingEntries, gradientDrawableOrange); // 黄色
        allDataSets.add(fallingSet);

        // 8. 分段5：低功率区域（X=4-5，蓝色填充）
        List<Entry> lowPower2Entries = new ArrayList<>();
        lowPower2Entries.add(new Entry(t4X, t4Y)); // 左上
        lowPower2Entries.add(new Entry(t5X, t4Y)); // 右上
        lowPower2Entries.add(new Entry(t5X, 0f));   // 右下（Y=0，严格闭合）
        lowPower2Entries.add(new Entry(t4X, 0f));   // 左下（Y=0，严格闭合）
        LineDataSet lowPower2Set = createFilledSegment(lowPower2Entries,gradientDrawableBlue); // 蓝色
        allDataSets.add(lowPower2Set);
    }

    private void initLine(List<ILineDataSet> allDataSets) {
        List<Entry> line1Entries = new ArrayList<>();
        line1Entries.add(new Entry(0f, t1Y));
        line1Entries.add(new Entry(t1X, t1Y));
        addEdgeHighlightLine(allDataSets, line1Entries, R.color.line_char_low);

        List<Entry> line2Entries = new ArrayList<>();
        line2Entries.add(new Entry(t1X, t1Y));
        line2Entries.add(new Entry(t2X, t2Y));
        line2Entries.add(new Entry(t3X, t3Y));
        line2Entries.add(new Entry(t4X, t4Y));
        addEdgeHighlightLine(allDataSets, line2Entries, R.color.engineer_charts_orange);

        List<Entry> line3Entries = new ArrayList<>();
        line3Entries.add(new Entry(t4X, t4Y));
        line3Entries.add(new Entry(t5X, t4Y));
        addEdgeHighlightLine(allDataSets, line3Entries, R.color.line_char_low);
    }

    /** 顶缘：底层轻 bloom + 明亮描边，贴近参考图边缘高亮。 */
    private void addEdgeHighlightLine(List<ILineDataSet> allDataSets, List<Entry> lineEntries, int colorId) {
        int color = ColorUtils.getColor(colorId);
        LineDataSet glow = createLineSplit(lineEntries, color);
        glow.setColor(Color.argb(96, Color.red(color), Color.green(color), Color.blue(color)));
        glow.setLineWidth(5.5f);
        allDataSets.add(glow);

        LineDataSet rim = createLineSplit(lineEntries, color);
        rim.setLineWidth(2.2f);
        allDataSets.add(rim);
    }

    private @NonNull LineDataSet createLineSplit(List<Entry> lineEntries, int colorArgb) {
        LineDataSet lineDataSet = new LineDataSet(lineEntries, "Power Line");
        lineDataSet.setColor(colorArgb);
        lineDataSet.setLineWidth(2.2f);
        lineDataSet.setDrawCircles(false);
        lineDataSet.setDrawCircleHole(false);
        lineDataSet.setDrawValues(false);
        lineDataSet.setDrawFilled(false);
        return lineDataSet;
    }

    // 工具方法：创建填充数据集（透明折线+指定颜色填充）
    private LineDataSet createFilledSegment(List<Entry> entries, Drawable gradientDrawable) {
        LineDataSet dataSet = new LineDataSet(entries, "Filled Segment");
        // 隐藏折线（仅显示填充）
        dataSet.setColor(Color.TRANSPARENT);
        dataSet.setLineWidth(0f);
        dataSet.setCircleRadius(0f);
        dataSet.setDrawCircleHole(false);
        dataSet.setDrawValues(false);
        dataSet.setDrawCircles(false);
        // 启用填充
        dataSet.setDrawFilled(true);
        dataSet.setFillAlpha(255); // 填充透明度（0-255，200=80%不透明）
        if (gradientDrawable!=null){
            dataSet.setFillDrawable(gradientDrawable);
        }
        // 强制填充到Y轴0点，确保紧贴X轴
        dataSet.setFillFormatter((dataSet1, dataProvider) -> 0f);
        return dataSet;
    }
    @Override
    public void destroy(){
        if (lineChart!=null){
            lineChart.destroyDrawingCache();
            lineChart.clear();
            lineChart = null;
        }
        this.context=null;
    }

    @Override
    public ViewGroup getView() {
        return this.lineChart;
    }
}
