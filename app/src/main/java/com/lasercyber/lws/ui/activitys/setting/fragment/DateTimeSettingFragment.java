package com.lasercyber.lws.ui.activitys.setting.fragment;

import android.app.Activity;
import android.content.Context;
import android.text.Editable;
import android.text.TextWatcher;
import android.text.TextUtils;
import android.view.View;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.NumberPicker;

import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.core.view.ViewCompat;

import com.blankj.utilcode.util.KeyboardUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.BR;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.setting.ui.DateTimeSettingUiLogic;
import com.lasercyber.lws.ui.bean.entity.DateTimeSetting;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.dialog.FrostDialog;
import com.lasercyber.lws.ui.component.dialog.NumberPickerUiUtils;
import com.lasercyber.lws.ui.databinding.FragmentDateTimeSettingBinding;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Locale;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * A simple {@link Fragment} subclass.
 * Date & Time settings.
 */
public class DateTimeSettingFragment extends BaseFragment<FragmentDateTimeSettingBinding> {
    private final ExecutorService executorService = Executors.newSingleThreadExecutor();
    private DateTimeSetting dateTimeSetting;
    private boolean suppressSwitchCallback = false;

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_date_time_setting;
    }

    @Override
    protected void bindViewModel() {
        super.bindViewModel();
        dateTimeSetting = new DateTimeSetting();
        binding.setVariable(BR.dateTimeSetting, dateTimeSetting);
        refreshState();
    }

    @Override
    protected void initView() {
        binding.autoDateTimeSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressSwitchCallback || !buttonView.isPressed()) {
                return;
            }
            GlobalSoundManager.playClickSound();
            if (!SystemSettingUtils.setAutoTimeEnabled(requireContext(), isChecked)) {
                ToastUtils.showShort(R.string.date_time_permission_denied);
            }
            refreshState();
        });
        binding.autoTimeZoneSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressSwitchCallback || !buttonView.isPressed()) {
                return;
            }
            GlobalSoundManager.playClickSound();
            if (!SystemSettingUtils.setAutoTimeZoneEnabled(requireContext(), isChecked)) {
                ToastUtils.showShort(R.string.date_time_permission_denied);
            }
            refreshState();
        });
        binding.dateRow.setOnClickListener(v -> {
            if (dateTimeSetting.isAutomaticDateTime()) {
                return;
            }
            showDatePicker();
        });
        binding.timeRow.setOnClickListener(v -> {
            if (dateTimeSetting.isAutomaticDateTime()) {
                return;
            }
            showTimePicker();
        });
        binding.timeZoneRow.setOnClickListener(v -> {
            if (dateTimeSetting.isAutomaticTimeZone()) {
                return;
            }
            showTimeZonePicker();
        });
    }

    @Override
    protected void initData() {
    }

    @Override
    public void onResume() {
        super.onResume();
        refreshState();
    }

    @Override
    public void onDestroyView() {
        suppressSwitchCallback = false;
        super.onDestroyView();
        executorService.shutdownNow();
    }

    private void postRefreshState() {
        if (binding == null) {
            return;
        }
        binding.getRoot().post(this::refreshState);
    }

    private void refreshState() {
        Context context = getContext();
        if (context == null || dateTimeSetting == null || binding == null) {
            return;
        }
        boolean autoTime = SystemSettingUtils.isAutoTimeEnabled(context);
        boolean autoTimeZone = SystemSettingUtils.isAutoTimeZoneEnabled(context);

        dateTimeSetting.setAutomaticDateTime(autoTime);
        dateTimeSetting.setAutomaticTimeZone(autoTimeZone);
        dateTimeSetting.setDateValue(formatDate(System.currentTimeMillis()));
        dateTimeSetting.setTimeValue(formatTime(System.currentTimeMillis()));
        dateTimeSetting.setTimeZoneValue(SystemSettingUtils.getCurrentTimeZoneId());
        suppressSwitchCallback = true;
        binding.autoDateTimeSwitch.setChecked(autoTime);
        binding.autoTimeZoneSwitch.setChecked(autoTimeZone);
        suppressSwitchCallback = false;
        boolean manualDateTimeEnabled = DateTimeSettingUiLogic.isManualDateTimeEnabled(autoTime);
        boolean manualTimeZoneEnabled = DateTimeSettingUiLogic.isManualTimeZoneEnabled(autoTimeZone);
        binding.dateRow.setEnabled(manualDateTimeEnabled);
        binding.timeRow.setEnabled(manualDateTimeEnabled);
        binding.timeZoneRow.setEnabled(manualTimeZoneEnabled);
        binding.dateArrow.setVisibility(manualDateTimeEnabled ? android.view.View.VISIBLE : android.view.View.INVISIBLE);
        binding.timeArrow.setVisibility(manualDateTimeEnabled ? android.view.View.VISIBLE : android.view.View.INVISIBLE);
        binding.timeZoneArrow.setVisibility(manualTimeZoneEnabled ? android.view.View.VISIBLE : android.view.View.INVISIBLE);

        boolean anyAuto = autoTime || autoTimeZone;
        if (!anyAuto) {
            dateTimeSetting.setAutoSyncStatus(getString(R.string.date_time_auto_sync_off));
            binding.setDateTimeSetting(dateTimeSetting);
            return;
        }
        if (!SystemSettingUtils.isNetworkConnected(context)) {
            dateTimeSetting.setAutoSyncStatus(getString(R.string.date_time_auto_sync_offline));
            binding.setDateTimeSetting(dateTimeSetting);
            return;
        }
        dateTimeSetting.setAutoSyncStatus(getString(R.string.date_time_auto_syncing));
        binding.setDateTimeSetting(dateTimeSetting);
        try {
            executorService.execute(() -> {
                boolean timeSuccess = true;
                boolean zoneSuccess = true;
                try {
                    if (autoTime) {
                        timeSuccess = SystemSettingUtils.syncDateTimeFromPublicNtp(context);
                    }
                    if (autoTimeZone) {
                        zoneSuccess = SystemSettingUtils.syncTimeZoneFromPublicService(context);
                    }
                } catch (Throwable throwable) {
                    timeSuccess = false;
                    zoneSuccess = false;
                }
                if (!isAdded() || getActivity() == null) {
                    return;
                }
                boolean finalTimeSuccess = timeSuccess;
                boolean finalZoneSuccess = zoneSuccess;
                getActivity().runOnUiThread(() -> {
                    if (dateTimeSetting == null || binding == null) {
                        return;
                    }
                    dateTimeSetting.setDateValue(formatDate(System.currentTimeMillis()));
                    dateTimeSetting.setTimeValue(formatTime(System.currentTimeMillis()));
                    dateTimeSetting.setTimeZoneValue(SystemSettingUtils.getCurrentTimeZoneId());
                    dateTimeSetting.setAutoSyncStatus(getString(
                            (finalTimeSuccess && finalZoneSuccess)
                                    ? R.string.date_time_auto_sync_ok
                                    : R.string.date_time_auto_sync_failed));
                    binding.setDateTimeSetting(dateTimeSetting);
                });
            });
        } catch (RejectedExecutionException ignored) {
            // Fragment view is being destroyed; skip this refresh cycle safely.
        }
    }

    private void showDatePicker() {
        final NumberPicker[] yearPicker = new NumberPicker[1];
        final NumberPicker[] monthPicker = new NumberPicker[1];
        final NumberPicker[] dayPicker = new NumberPicker[1];
        FrostDialog.prompt(requireContext())
                .widthDimen(R.dimen.frost_dialog_date_picker_width)
                .title(R.string.date_time_set_date)
                .customBodyView(R.layout.dialog_frost_body_date_picker, body -> {
                    yearPicker[0] = body.findViewById(R.id.np_year);
                    monthPicker[0] = body.findViewById(R.id.np_month);
                    dayPicker[0] = body.findViewById(R.id.np_day);

                    Calendar calendar = Calendar.getInstance();
                    yearPicker[0].setMinValue(2000);
                    yearPicker[0].setMaxValue(2099);
                    yearPicker[0].setValue(calendar.get(Calendar.YEAR));
                    monthPicker[0].setMinValue(1);
                    monthPicker[0].setMaxValue(12);
                    monthPicker[0].setValue(calendar.get(Calendar.MONTH) + 1);
                    dayPicker[0].setMinValue(1);
                    dayPicker[0].setMaxValue(calendar.getActualMaximum(Calendar.DAY_OF_MONTH));
                    dayPicker[0].setValue(calendar.get(Calendar.DAY_OF_MONTH));
                    stylePicker(yearPicker[0], false);
                    stylePicker(monthPicker[0], true);
                    stylePicker(dayPicker[0], true);

                    NumberPicker.OnValueChangeListener dateChangeListener = (picker, oldVal, newVal) -> {
                        Calendar temp = Calendar.getInstance();
                        temp.set(Calendar.YEAR, yearPicker[0].getValue());
                        temp.set(Calendar.MONTH, monthPicker[0].getValue() - 1);
                        dayPicker[0].setMaxValue(temp.getActualMaximum(Calendar.DAY_OF_MONTH));
                        if (dayPicker[0].getValue() > dayPicker[0].getMaxValue()) {
                            dayPicker[0].setValue(dayPicker[0].getMaxValue());
                        }
                    };
                    yearPicker[0].setOnValueChangedListener(dateChangeListener);
                    monthPicker[0].setOnValueChangedListener(dateChangeListener);
                })
                .confirmText(R.string.confirm_text)
                .cancelText(R.string.cancel_text)
                .onConfirm(() -> {
                    GlobalSoundManager.playClickSound();
                    Calendar target = Calendar.getInstance();
                    target.setTimeInMillis(System.currentTimeMillis());
                    target.set(Calendar.YEAR, yearPicker[0].getValue());
                    target.set(Calendar.MONTH, monthPicker[0].getValue() - 1);
                    target.set(Calendar.DAY_OF_MONTH, dayPicker[0].getValue());
                    Context context = getContext();
                    if (context != null && !SystemSettingUtils.setDateAndTimeMillis(context, target.getTimeInMillis())) {
                        ToastUtils.showShort(R.string.date_time_set_failed);
                    }
                    postRefreshState();
                })
                .show();
    }

    private void showTimePicker() {
        final NumberPicker[] hourPicker = new NumberPicker[1];
        final NumberPicker[] minutePicker = new NumberPicker[1];
        FrostDialog.prompt(requireContext())
                .widthDimen(R.dimen.frost_dialog_date_picker_width)
                .title(R.string.date_time_set_time)
                .customBodyView(R.layout.dialog_frost_body_time_picker, body -> {
                    hourPicker[0] = body.findViewById(R.id.np_hour_custom);
                    minutePicker[0] = body.findViewById(R.id.np_minute_custom);

                    Calendar calendar = Calendar.getInstance();
                    hourPicker[0].setMinValue(0);
                    hourPicker[0].setMaxValue(23);
                    minutePicker[0].setMinValue(0);
                    minutePicker[0].setMaxValue(59);
                    hourPicker[0].setValue(calendar.get(Calendar.HOUR_OF_DAY));
                    minutePicker[0].setValue(calendar.get(Calendar.MINUTE));
                    hourPicker[0].setFormatter(value -> String.format(Locale.getDefault(), "%02d", value));
                    minutePicker[0].setFormatter(value -> String.format(Locale.getDefault(), "%02d", value));
                    stylePicker(hourPicker[0], true);
                    stylePicker(minutePicker[0], true);
                })
                .confirmText(R.string.confirm_text)
                .cancelText(R.string.cancel_text)
                .onConfirm(() -> {
                    GlobalSoundManager.playClickSound();
                    Calendar target = Calendar.getInstance();
                    target.setTimeInMillis(System.currentTimeMillis());
                    target.set(Calendar.HOUR_OF_DAY, hourPicker[0].getValue());
                    target.set(Calendar.MINUTE, minutePicker[0].getValue());
                    target.set(Calendar.SECOND, 0);
                    target.set(Calendar.MILLISECOND, 0);
                    Context context = getContext();
                    if (context != null && !SystemSettingUtils.setDateAndTimeMillis(context, target.getTimeInMillis())) {
                        ToastUtils.showShort(R.string.date_time_set_failed);
                    }
                    postRefreshState();
                })
                .show();
    }

    private void showTimeZonePicker() {
        Activity activity = getActivity();
        final int[] hostSoftInputMode = {WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
                | WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN};
        if (activity != null && activity.getWindow() != null) {
            hostSoftInputMode[0] = activity.getWindow().getAttributes().softInputMode;
            activity.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
                    | WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN);
        }
        final EditText[] searchInputRef = new EditText[1];
        final String[] selectedZone = new String[1];
        Runnable restoreHostInsets = () -> {
            hideKeyboardAndResetInsets(searchInputRef[0]);
            Activity hostActivity = getActivity();
            if (hostActivity != null && hostActivity.getWindow() != null) {
                hostActivity.getWindow().setSoftInputMode(hostSoftInputMode[0]);
                View root = hostActivity.findViewById(android.R.id.content);
                if (root != null) {
                    root.post(() -> {
                        ViewCompat.requestApplyInsets(root);
                        root.requestLayout();
                    });
                }
            }
        };
        FrostDialog.prompt(requireContext())
                .widthDimen(R.dimen.frost_dialog_date_picker_width)
                .title(R.string.date_time_select_time_zone)
                .onCancel(restoreHostInsets)
                .customBodyView(R.layout.dialog_frost_body_timezone_picker, body -> {
                    String[] ids = SystemSettingUtils.getAvailableTimeZoneIds();
                    String current = SystemSettingUtils.getCurrentTimeZoneId();
                    EditText searchInput = body.findViewById(R.id.et_timezone_search);
                    searchInputRef[0] = searchInput;
                    ListView listView = body.findViewById(R.id.lv_timezone);

                    ArrayList<String> allZones = new ArrayList<>();
                    for (String id : ids) {
                        allZones.add(id);
                    }
                    ArrayList<String> filteredZones = new ArrayList<>(allZones);
                    selectedZone[0] = TextUtils.isEmpty(current) ? "" : current;

                    ArrayAdapter<String> adapter = new ArrayAdapter<>(requireContext(),
                            R.layout.item_timezone_choice, R.id.ctv_timezone_name, filteredZones);
                    listView.setAdapter(adapter);

                    if (!TextUtils.isEmpty(current)) {
                        int idx = filteredZones.indexOf(current);
                        if (idx >= 0) {
                            listView.setItemChecked(idx, true);
                            listView.setSelection(idx);
                        }
                    }

                    listView.setOnItemClickListener((parent, view, position, id) -> {
                        selectedZone[0] = filteredZones.get(position);
                        hideKeyboardAndResetInsets(searchInput);
                    });
                    searchInput.addTextChangedListener(new TextWatcher() {
                        @Override
                        public void beforeTextChanged(CharSequence s, int start, int count, int after) {
                        }

                        @Override
                        public void onTextChanged(CharSequence s, int start, int before, int count) {
                        }

                        @Override
                        public void afterTextChanged(Editable s) {
                            String query = s == null ? "" : s.toString().trim().toLowerCase(Locale.ROOT);
                            filteredZones.clear();
                            if (TextUtils.isEmpty(query)) {
                                filteredZones.addAll(allZones);
                            } else {
                                ArrayList<String> exactMatches = new ArrayList<>();
                                ArrayList<String> fuzzyMatches = new ArrayList<>();
                                for (String zone : allZones) {
                                    String zoneLower = zone.toLowerCase(Locale.ROOT);
                                    if (zoneLower.equals(query) || zoneLower.endsWith("/" + query)) {
                                        exactMatches.add(zone);
                                    } else if (zoneLower.contains(query)) {
                                        fuzzyMatches.add(zone);
                                    }
                                }
                                filteredZones.addAll(exactMatches);
                                filteredZones.addAll(fuzzyMatches);
                            }
                            adapter.notifyDataSetChanged();
                            if (filteredZones.isEmpty()) {
                                selectedZone[0] = "";
                                listView.clearChoices();
                                return;
                            }
                            int idx = TextUtils.isEmpty(selectedZone[0]) ? -1 : filteredZones.indexOf(selectedZone[0]);
                            if (idx < 0) {
                                idx = 0;
                                selectedZone[0] = filteredZones.get(0);
                            }
                            listView.setItemChecked(idx, true);
                            listView.setSelection(idx);
                        }
                    });
                })
                .confirmText(R.string.confirm_text)
                .cancelText(R.string.cancel_text)
                .onConfirm(() -> {
                    hideKeyboardAndResetInsets(searchInputRef[0]);
                    String selected = selectedZone[0];
                    if (!TextUtils.isEmpty(selected) && !SystemSettingUtils.setTimeZone(requireContext(), selected)) {
                        ToastUtils.showShort(R.string.date_time_set_failed);
                    }
                    restoreHostInsets.run();
                    postRefreshState();
                })
                .show();
    }

    private String formatDate(long millis) {
        return new SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(millis);
    }

    private String formatTime(long millis) {
        return new SimpleDateFormat("HH:mm", Locale.getDefault()).format(millis);
    }

    private void stylePicker(NumberPicker picker, boolean wrap) {
        NumberPickerUiUtils.applyFrostPickerStyle(requireContext(), picker, wrap);
    }

    private void hideKeyboardAndResetInsets(@Nullable EditText searchInput) {
        if (searchInput != null) {
            searchInput.clearFocus();
            KeyboardUtils.hideSoftInput(searchInput);
        }

        Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        View root = activity.findViewById(android.R.id.content);
        if (root != null) {
            root.post(() -> {
                forceHideImeFromActivity(activity, root);
                ViewCompat.requestApplyInsets(root);
                root.requestLayout();
                root.invalidate();
            });
            root.postDelayed(() -> {
                forceHideImeFromActivity(activity, root);
                ViewCompat.requestApplyInsets(root);
                root.requestLayout();
                root.invalidate();
            }, 80);
        }
    }

    private void forceHideImeFromActivity(Activity activity, View root) {
        InputMethodManager imm =
                (InputMethodManager) activity.getSystemService(Context.INPUT_METHOD_SERVICE);
        if (imm == null) {
            return;
        }
        View decor = activity.getWindow() == null ? null : activity.getWindow().getDecorView();
        if (decor != null && decor.getWindowToken() != null) {
            imm.hideSoftInputFromWindow(decor.getWindowToken(), 0);
        }
        if (root.getWindowToken() != null) {
            imm.hideSoftInputFromWindow(root.getWindowToken(), 0);
        }
    }
}
