package com.lasercyber.lws.ui.bean.entity.vo;

import lombok.Data;

/*告警对话框内容*/
@Data
public class WarnDialogVo {

    private Integer type;//类型 = 0 告警 ； = 1 提示；

    private String content; // 弹窗内容

    private String title;//弹窗标题

    private Boolean isShowProgress; //是否显示progress统计图表

    /* 进度0-50：绿色
    进度50-80：橙色
     进度80-100：红色*/
    private Integer progress;// 图表显示值  0 - 100

    private String unit = "-"; //图表单位 kpa

    //图表内容标题 如：context.getResources().getString(R.string.machine_blow_title)
    private String proTitle;

    //图表内容说明 如：context.getResources().getString(R.string.machine_blow_content)
    private String proContent;

    private Integer max;
    /**
     * 告警错误码
     */
    private String errorCode;

    /**
     * Optional confirm button text override.
     */
    private String buttonText;

    /**
     * Runs only when the user taps the confirm button.
     */
    private transient Runnable onConfirm;

    /**
     * Optional jump button label; when set, the dialog shows confirm (left) and jump (right).
     */
    private String jumpButtonText;

    /**
     * Runs only when the user taps the jump button.
     */
    private transient Runnable onJump;

    /**
     * When true, external auto-close paths (e.g. Modbus fault recovery via {@code closeWarn})
     * must not dismiss this episode until the operator confirms on the dialog.
     * Set when the dialog is built or enqueued; not toggled at dismiss time.
     */
    private boolean resistExternalAutoClose;

}
