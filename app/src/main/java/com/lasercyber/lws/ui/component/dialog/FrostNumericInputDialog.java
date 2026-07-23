package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.Context;
import android.text.InputFilter;
import android.text.InputType;
import android.view.View;
import android.widget.EditText;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.StringRes;

import com.blankj.utilcode.util.ActivityUtils;
import com.lasercyber.lws.frostui.control.FrostNumericStepperLogic;
import com.lasercyber.lws.frostui.control.interop.FrostNumericStepperView;
import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.ime.ImeAction;
import com.lasercyber.lws.ime.core.ImeConfig;
import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig;
import com.lasercyber.lws.ime.interop.ImeNumericFieldBridge;
import com.lasercyber.lws.ime.interop.ImeOverlayHost;
import com.lasercyber.lws.ime.interop.ImeOverlaySpec;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;

/**
 * Numeric parameter input on {@link FrostDialog} for engineer-mode and advanced-settings fields.
 */
public final class FrostNumericInputDialog {

    public interface OnInputConfirmedListener {
        /** @return true to dismiss the dialog */
        boolean onInputConfirmed(@NonNull String inputData);
    }

    public static final class Config {
        private final CharSequence title;
        @Nullable
        private final String defaultInput;
        @Nullable
        private final String descText;
        private final int inputType;
        @Nullable
        private final InputFilter[] inputFilters;
        private final boolean decimalStep;
        private final java.math.BigDecimal decimalStepSize;
        private final boolean showStepper;
        private final int minValue;
        private final int maxValue;

        private Config(Builder builder) {
            this.title = builder.title;
            this.defaultInput = builder.defaultInput;
            this.descText = builder.descText;
            this.inputType = builder.inputType;
            this.inputFilters = builder.inputFilters;
            this.decimalStep = builder.decimalStep;
            this.decimalStepSize = builder.decimalStepSize;
            this.showStepper = builder.showStepper;
            this.minValue = builder.minValue;
            this.maxValue = builder.maxValue;
        }

        public static Builder builder(@NonNull CharSequence title) {
            return new Builder(title);
        }

        public static final class Builder {
            private CharSequence title;
            @Nullable
            private String defaultInput = "";
            @Nullable
            private String descText;
            private int inputType = InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_DECIMAL;
            @Nullable
            private InputFilter[] inputFilters;
            private boolean decimalStep;
            private java.math.BigDecimal decimalStepSize = FrostNumericStepperLogic.METRIC_DECIMAL_STEP;
            private boolean showStepper = true;
            private int minValue;
            private int maxValue = Integer.MAX_VALUE;

            private Builder(@NonNull CharSequence title) {
                this.title = title;
            }

            public Builder titleUnit(@NonNull Context context, @StringRes int unitResId) {
                this.title = context.getString(
                        R.string.input_dialog_title_with_unit, title, context.getString(unitResId));
                return this;
            }

            public Builder defaultInput(@Nullable String defaultInput) {
                this.defaultInput = defaultInput;
                return this;
            }

            public Builder descText(@Nullable String descText) {
                this.descText = descText;
                return this;
            }

            public Builder integerNumberInput() {
                this.inputType = InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_DECIMAL;
                this.inputFilters = new InputFilter[]{FrostNumericStepperLogic.integerDigitFilter()};
                this.decimalStep = false;
                this.showStepper = true;
                return this;
            }

            public Builder decimalNumberInput() {
                this.inputType = InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_DECIMAL;
                this.inputFilters = null;
                this.decimalStep = true;
                this.decimalStepSize = FrostNumericStepperLogic.METRIC_DECIMAL_STEP;
                this.showStepper = true;
                return this;
            }

            public Builder imperialDecimalNumberInput() {
                decimalNumberInput();
                this.decimalStepSize = FrostNumericStepperLogic.IMPERIAL_DECIMAL_STEP;
                return this;
            }

            public Builder signedIntegerInput() {
                this.inputType = InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_SIGNED;
                this.inputFilters = new InputFilter[]{FrostNumericStepperLogic.signedIntegerFilter()};
                this.decimalStep = false;
                this.showStepper = true;
                return this;
            }

            public Builder showStepper(boolean showStepper) {
                this.showStepper = showStepper;
                return this;
            }

            public Builder minValue(int minValue) {
                this.minValue = minValue;
                return this;
            }

            public Builder maxValue(int maxValue) {
                this.maxValue = maxValue;
                return this;
            }

            public Config build() {
                return new Config(this);
            }
        }
    }

    private FrostNumericInputDialog() {
    }

    public static boolean show(
            @NonNull Context context,
            @NonNull Config config,
            @NonNull OnInputConfirmedListener listener) {
        Context hostContext = resolveHostContext(context);
        final EditText[] inputHolder = new EditText[1];
        final FrostDialog.Handle[] handleHolder = new FrostDialog.Handle[1];
        final OnInputConfirmedListener[] listenerHolder = new OnInputConfirmedListener[]{listener};

        boolean signed = (config.inputType & InputType.TYPE_NUMBER_FLAG_SIGNED) != 0;
        boolean decimal = config.decimalStep;
        ImeOverlaySpec imeOverlay = ImeOverlaySpec.create(
                ImeConfig.withEnterKey(ImeEnterKeyConfig.done()),
                ImeNumericFieldBridge.fieldTypeForDialog(signed, decimal),
                action -> {
                    if (action instanceof ImeAction.Done) {
                        trySubmit(inputHolder[0], handleHolder[0], listenerHolder[0]);
                        return true;
                    }
                    return false;
                },
                ImeNumericFieldBridge.policyOverrideForDialog(signed, decimal));

        FrostDialog.Handle handle = FrostDialog.prompt(hostContext)
                .title(config.title)
                .widthDimen(R.dimen.frost_dialog_numeric_input_width)
                .imeOverlay(imeOverlay)
                .customBodyView(R.layout.dialog_frost_body_numeric_input,
                        body -> bindBody(body, config, inputHolder))
                .showActionBar(false)
                .dismissOnScrimClick(true)
                .show();

        handleHolder[0] = handle;
        if (handle == null) {
            return false;
        }

        Activity activity = FrostOverlayHost.findActivity(hostContext);
        View overlay = handle.getRootView();
        FrostNumericStepperView stepper =
                (FrostNumericStepperView) handle.findViewById(R.id.frost_dialog_numeric_stepper);
        if (stepper != null) {
            stepper.setOnEditTextReadyListener(editText -> {
                inputHolder[0] = editText;
                editText.setShowSoftInputOnFocus(false);
                if (activity != null && overlay != null) {
                    ImeOverlayHost.scheduleKeyboardAfterDialogShown(activity, overlay, editText);
                }
            });
        }
        return true;
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
            @NonNull Config config,
            @NonNull EditText[] inputHolder) {
        FrostNumericStepperView stepper = body.findViewById(R.id.frost_dialog_numeric_stepper);
        if (stepper == null) {
            return;
        }

        stepper.setInputType(config.inputType);
        stepper.setInputFilters(config.inputFilters);
        stepper.setDescriptionText(config.descText);
        stepper.setShowStepper(config.showStepper);
        stepper.setDecimalStep(config.decimalStep, config.decimalStepSize);
        stepper.setMinMax(config.minValue, config.maxValue);
        stepper.applyDefaultInput(config.defaultInput, config.inputType);
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
