package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.content.Context;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;

public class OperationDialogBuilder {
    /**
     * 操作失败
     * @param context
     * @param msgId
     */
    public static void openErrorDialog(Context context, int msgId){
        GlobalDialogUtil.singletonOpen(context,0 , context.getString(R.string.operation_failed_text),context.getString(msgId) );
    }

    public static void openErrorDialog(Context context, String message) {
        GlobalDialogUtil.singletonOpen(context, 0, context.getString(R.string.operation_failed_text), message);
    }

    /**
     * 操作成功
     * @param context
     * @param msgId
     */
    public static void openSuccessDialog(Context context, int msgId){
        String msg="";
        if (msgId>0){
            msg=context.getString(msgId);
        }
        GlobalDialogUtil.singletonOpen(context,1 , context.getString(R.string.operation_successful_text),msg );
    }
    public static void closeDialog(){
        GlobalDialogUtil.closeDialog();
    }
}
