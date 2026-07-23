package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.Context;
import android.text.InputType;
import android.text.TextUtils;
import android.view.View;
import android.widget.EditText;
import android.widget.ImageButton;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.StringRes;

import com.blankj.utilcode.util.ActivityUtils;
import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.ime.ImeAction;
import com.lasercyber.lws.ime.core.ImeConfig;
import com.lasercyber.lws.ime.engine.EditTextImeInputConnection;
import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig;
import com.lasercyber.lws.ime.field.ImeFieldType;
import com.lasercyber.lws.ime.interop.ImeOverlayHost;
import com.lasercyber.lws.ime.interop.ImeOverlaySpec;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;

/**
 * Text-input prompt on {@link FrostDialog} for non-numeric HMI fields.
 */
public final class FrostTextInputDialog {

    public interface OnInputConfirmedListener {
        /** @return true to dismiss the dialog */
        boolean onInputConfirmed(@NonNull String inputData);
    }

    private FrostTextInputDialog() {
    }

    public static boolean show(
            @NonNull Context context,
            @StringRes int titleRes,
            @Nullable String defaultInput,
            @NonNull OnInputConfirmedListener listener) {
        return show(context, context.getString(titleRes), defaultInput, ImeFieldType.Text, listener);
    }

    public static boolean show(
            @NonNull Context context,
            @NonNull CharSequence title,
            @Nullable String defaultInput,
            @NonNull ImeFieldType fieldType,
            @NonNull OnInputConfirmedListener listener) {
        Context hostContext = resolveHostContext(context);
        final EditText[] inputHolder = new EditText[1];
        final FrostDialog.Handle[] handleHolder = new FrostDialog.Handle[1];
        final OnInputConfirmedListener[] listenerHolder = new OnInputConfirmedListener[]{listener};
        boolean maskedInput = fieldType == ImeFieldType.WiFi || fieldType == ImeFieldType.Password;

        ImeOverlaySpec imeOverlay = ImeOverlaySpec.create(
                ImeConfig.withEnterKey(ImeEnterKeyConfig.done()),
                fieldType,
                action -> {
                    if (action instanceof ImeAction.Done) {
                        trySubmit(inputHolder[0], handleHolder[0], listenerHolder[0]);
                        return true;
                    }
                    return false;
                });

        FrostDialog.Handle handle = FrostDialog.prompt(hostContext)
                .title(title)
                .widthDimen(R.dimen.frost_dialog_numeric_input_width)
                .imeOverlay(imeOverlay)
                .customBodyView(
                        maskedInput
                                ? R.layout.dialog_frost_body_password_input
                                : R.layout.dialog_frost_body_text_input,
                        body -> bindBody(body, defaultInput, fieldType, inputHolder))
                .showActionBar(false)
                .dismissOnScrimClick(true)
                .show();

        handleHolder[0] = handle;
        if (handle == null) {
            return false;
        }

        Activity activity = FrostOverlayHost.findActivity(hostContext);
        View overlay = handle.getRootView();
        EditText input = inputHolder[0];
        if (activity != null && overlay != null && input != null) {
            ImeOverlayHost.scheduleKeyboardAfterDialogShown(activity, overlay, input);
        }
        return true;
    }

    public static boolean show(
            @NonNull Context context,
            @StringRes int titleRes,
            @Nullable String defaultInput,
            @NonNull ImeFieldType fieldType,
            @NonNull OnInputConfirmedListener listener) {
        return show(context, context.getString(titleRes), defaultInput, fieldType, listener);
    }

    @Deprecated
    public static boolean show(
            @NonNull Context context,
            @NonNull CharSequence title,
            @Nullable String defaultInput,
            @NonNull OnInputConfirmedListener listener) {
        return show(context, title, defaultInput, ImeFieldType.Text, listener);
    }

    private static Context resolveHostContext(@NonNull Context context) {
        Activity activity = FrostOverlayHost.findActivity(context);
        if (activity != null) {
            return activity;
        }
        Activity top = ActivityUtils.getTopActivity();
        return top != null ? top : context;
    }

    private static void bindBody(
            @NonNull View body,
            @Nullable String defaultInput,
            @NonNull ImeFieldType fieldType,
            @NonNull EditText[] inputHolder) {
        EditText input = body.findViewById(R.id.frost_dialog_text_input);
        inputHolder[0] = input;
        if (input == null) {
            return;
        }
        input.setShowSoftInputOnFocus(false);
        if (fieldType == ImeFieldType.WiFi || fieldType == ImeFieldType.Password) {
            input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
            ImageButton visibilityToggle = body.findViewById(R.id.frost_dialog_text_input_visibility);
            bindPasswordVisibilityToggle(input, visibilityToggle);
        }

        if (!TextUtils.isEmpty(defaultInput)) {
            input.setText(defaultInput);
            input.setSelection(defaultInput.length());
        }
    }

    private static void bindPasswordVisibilityToggle(
            @NonNull EditText password,
            @Nullable ImageButton visibilityToggle) {
        if (visibilityToggle == null) {
            return;
        }
        EditTextImeInputConnection connection = new EditTextImeInputConnection(password, action -> false);
        Runnable syncToggleIcon = () -> {
            boolean visible = connection.isPasswordVisible();
            visibilityToggle.setImageResource(
                    visible ? R.drawable.ic_password_visibility : R.drawable.ic_password_visibility_off);
            visibilityToggle.setContentDescription(
                    password.getContext().getString(
                            visible ? R.string.wifi_dialog_hide_password
                                    : R.string.wifi_dialog_show_password));
        };
        visibilityToggle.setOnClickListener(v -> {
            connection.setPasswordVisible(!connection.isPasswordVisible());
            syncToggleIcon.run();
        });
        syncToggleIcon.run();
    }

    private static void trySubmit(
            @Nullable EditText input,
            @Nullable FrostDialog.Handle handle,
            @Nullable OnInputConfirmedListener listener) {
        GlobalSoundManager.playClickSound();
        if (input == null || listener == null) {
            return;
        }
        String value = input.getText() != null ? input.getText().toString().trim() : "";
        if (listener.onInputConfirmed(value)) {
            if (handle != null) {
                handle.dismiss();
            } else {
                FrostDialog.dismiss();
            }
        }
    }
}
