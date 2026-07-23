package com.lasercyber.lws.ui.component.dialog;

import android.content.Context;
import android.content.res.Resources;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.ui.LabelValueListItem;
import com.lasercyber.lws.ui.common.utils.ProcessParameterDisplayRows;
import com.lasercyber.lws.ui.component.layout.InsetLabelValueList;
import com.lasercyber.lws.ui.component.layout.InsetList;

import java.util.List;

/** OK-only FrostedGlass summary after remote {@code command.send_process_param} delivery. */
public final class RemoteProcessParamReceivedDialog {

    private RemoteProcessParamReceivedDialog() {
    }

    @Nullable
    public static FrostDialog.Handle show(
            @NonNull Context context,
            @NonNull ProcessParametersData data,
            boolean useMMUnit,
            @Nullable Runnable onDismissed) {
        List<LabelValueListItem> rows = ProcessParameterDisplayRows.build(data, useMMUnit, context);

        return FrostDialog.prompt(context)
                .title(R.string.remote_process_param_received_title)
                .maxHeightPx(resolveMaxDialogHeightPx(context))
                .expandBodyScroll(true)
                .customBodyView(R.layout.dialog_frost_body_readonly_parameter_list, body -> bindBody(body, rows))
                .showActionBar(true)
                .showCancel(false)
                .showConfirm(true)
                .confirmText(R.string.ok_text)
                .dismissOnScrimClick(true)
                .onConfirm(onDismissed)
                .onCancel(onDismissed)
                .show();
    }

    static int resolveMaxDialogHeightPx(@NonNull Context context) {
        Resources resources = context.getResources();
        int screenHeight = resources.getDisplayMetrics().heightPixels;
        int screenMargin = resources.getDimensionPixelSize(R.dimen.remote_process_param_dialog_screen_margin);
        return Math.max(0, screenHeight - screenMargin * 2);
    }

    private static void bindBody(@NonNull View body, @NonNull List<LabelValueListItem> rows) {
        InsetList list = body.findViewById(R.id.frost_dialog_readonly_parameter_list);
        InsetLabelValueList.bind(list, rows);
    }
}
