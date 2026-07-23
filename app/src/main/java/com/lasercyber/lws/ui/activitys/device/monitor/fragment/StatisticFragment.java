package com.lasercyber.lws.ui.activitys.device.monitor.fragment;

import android.os.Bundle;
import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.os.Build;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.common.utils.ResourceUtils;
import com.lasercyber.lws.ui.common.utils.web.HomeLayoutUtils;
import com.lasercyber.lws.ui.databinding.FragmentStatisticBinding;

import cn.hutool.core.convert.Convert;

public class StatisticFragment extends BaseFragment<FragmentStatisticBinding> {
    // 参数key（常量）
    public static final String KEY_VALUE = "value";

    public static final String KEY_UNIT = "unit";
    public static final String KEY_DESC = "desc";
    public static final String KEY_TYPE = "type";

    public Integer getTypeKey(){
        Bundle args = getArguments();
        return args.getInt(KEY_TYPE);
    }
    @Override
    protected int getLayoutId() {
        return R.layout.fragment_statistic;
    }

    @Override
    protected void initView() {}

    /*初始化数据*/
    @Override
    protected void initData() {
        // 绑定控件
        Bundle args = getArguments();
        if( binding == null ){
            return ;
        }
        // 设置描述
        String desc = args.getString( KEY_DESC, "none" );
        binding.desc.setText( desc );
        // 获取对话框类型
        int type = args.getInt( KEY_TYPE, 1 );
        showConfig(args,type);

        if ( type == HomeLayoutUtils.weldingRatio || type == HomeLayoutUtils.rinseRatio || type == HomeLayoutUtils.cuttingRatio ) {
            String progress = args.getString( KEY_VALUE, "0" );
            binding.progress.setProgress( Convert.toInt(progress), type );
            return;
        }

        String value = args.getString(KEY_VALUE, "0");
        String unit = args.getString(KEY_UNIT, "val");

        binding.dataValueData.setText( value );
        if (type != HomeLayoutUtils.commonMaterials) {
            this.judgeValueOnSize(value);
            binding.dataUnit.setVisibility(View.VISIBLE);
            LinearLayout.LayoutParams params =
                    (LinearLayout.LayoutParams) binding.dataValueData.getLayoutParams();
            params.width = ViewGroup.LayoutParams.WRAP_CONTENT;
            params.height = ViewGroup.LayoutParams.MATCH_PARENT;
            params.weight = 0f;
            binding.dataValueData.setLayoutParams(params);
            binding.dataValueData.setMaxLines(2);
            binding.dataValueData.setIncludeFontPadding(true);
            binding.dataValueData.setLineSpacing(0f, 1.0f);
        } else {
            // Frequent Usage is plain text instead of numeric value.
            binding.dataValueData.setTextSize(TypedValue.COMPLEX_UNIT_SP, 30);
            binding.dataUnit.setVisibility(View.GONE);
            binding.dataValueData.setAutoSizeTextTypeUniformWithConfiguration(
                    10, 30, 1, TypedValue.COMPLEX_UNIT_SP
            );
            setMarginTop(0);
            LinearLayout.LayoutParams params =
                    (LinearLayout.LayoutParams) binding.dataValueData.getLayoutParams();
            params.width = ViewGroup.LayoutParams.MATCH_PARENT;
            params.height = ViewGroup.LayoutParams.MATCH_PARENT;
            params.weight = 0f;
            binding.dataValueData.setLayoutParams(params);
            binding.dataValueData.setMaxLines(4);
            binding.dataValueData.setIncludeFontPadding(false);
            binding.dataValueData.setLineSpacing(0f, 0.8f);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                binding.dataValueData.setBreakStrategy(android.text.Layout.BREAK_STRATEGY_HIGH_QUALITY);
                binding.dataValueData.setHyphenationFrequency(android.text.Layout.HYPHENATION_FREQUENCY_NORMAL);
            }
        }

        if( type == HomeLayoutUtils.commonMaterials ){
            binding.dataValueData.setTextAlignment(View.TEXT_ALIGNMENT_VIEW_START);
            binding.dataValueData.setGravity(android.view.Gravity.START | android.view.Gravity.CENTER_VERTICAL);
        } else {
            binding.dataValueData.setTextAlignment(View.TEXT_ALIGNMENT_VIEW_START);
            binding.dataValueData.setGravity(android.view.Gravity.START | android.view.Gravity.CENTER_VERTICAL);
        }
        binding.dataUnit.setText( unit );
    }

    /*根据数值设置字体大小，大于999*/
    private void judgeValueOnSize( String value ){
        Integer anInt = Convert.toInt( value );

        if (anInt != null && anInt > 999) {
            binding.dataValueData.setTextSize(TypedValue.COMPLEX_UNIT_SP, 42);
            binding.dataUnit.setTextSize(TypedValue.COMPLEX_UNIT_SP, 26);

            this.setMarginTop(10);
        }else{
            binding.dataValueData.setTextSize(TypedValue.COMPLEX_UNIT_SP, 64);
            binding.dataUnit.setTextSize(TypedValue.COMPLEX_UNIT_SP, 32);

            this.setMarginTop(0);
        }
    }

    private void setMarginTop(int marginTop){
        int top = dp2px(marginTop);
        LinearLayout.LayoutParams params = (LinearLayout.LayoutParams)binding.dataUnit.getLayoutParams();
        params.topMargin = top;
        binding.dataValueData.setLayoutParams(params);

        LinearLayout.LayoutParams params1 = (LinearLayout.LayoutParams)binding.dataValueData.getLayoutParams();
        params1.topMargin = top;
        binding.dataValueData.setLayoutParams( params1 );
    }

    /*做显示处理，如果类型=3 =4 则文字位置要调整Margin*/
    private void showConfig( Bundle args, int type ){
        // 设置描述
        binding.desc.setText(args.getString(KEY_DESC,"none"));
        binding.dataLayout.setVisibility(View.VISIBLE);
        binding.progress.setVisibility(View.GONE);

        if(type ==HomeLayoutUtils.weldingRatio || type ==HomeLayoutUtils.rinseRatio || type ==HomeLayoutUtils.cuttingRatio){
            LinearLayout.LayoutParams layoutParams = (LinearLayout.LayoutParams)binding.desc.getLayoutParams();
            int dp = ResourceUtils.dp2px(getContext(), -60);
            layoutParams.topMargin = dp;
            binding.desc.setLayoutParams(layoutParams);

            binding.dataLayout.setVisibility(View.GONE);
            binding.progress.setVisibility(View.VISIBLE);
        }
        if(type == HomeLayoutUtils.jobLength){
            LinearLayout.LayoutParams layoutParams = (LinearLayout.LayoutParams)binding.desc.getLayoutParams();
            binding.desc.setLayoutParams(layoutParams);
        }
    }

    // 便捷的Fragment创建方法（封装参数传递）
    public static StatisticFragment newInstance(String value, String unit, String desc, int type) {
        StatisticFragment fragment = new StatisticFragment();
        Bundle args = new Bundle();
        args.putString(KEY_VALUE, value);
        args.putString(KEY_UNIT, unit);
        args.putString(KEY_DESC, desc);
        args.putInt(KEY_TYPE,type);
        fragment.setArguments(args);
        return fragment;
    }

    // 核心：公开的更新方法，供Activity调用
    public void updateFragmentData(String value, String unit, String desc, int type) {
        // 设置描述
        Bundle args = new Bundle();
        args.putString(KEY_VALUE, value);
        args.putString(KEY_UNIT, unit);
        args.putString(KEY_DESC, desc);
        args.putInt(KEY_TYPE,type);

        setArguments(args);
        initData();
    }

    private int dp2px(float dp) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, getResources().getDisplayMetrics());
    }



}
