package com.lasercyber.lws.ui.activitys.setting.fragment;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.Editable;
import android.text.TextUtils;
import android.text.TextWatcher;
import android.util.Log;
import android.view.View;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.NumberPicker;
import android.widget.RadioButton;
import android.widget.SeekBar;

import androidx.annotation.Nullable;
import androidx.core.view.ViewCompat;
import com.blankj.utilcode.util.KeyboardUtils;
import com.blankj.utilcode.util.LanguageUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.other.WifiActivity;
import com.lasercyber.lws.ui.activitys.setting.DeviceSettingActivity;
import com.lasercyber.lws.ui.activitys.setting.HttpProxySettingsActivity;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.common.network.proxy.HttpProxySettings;
import com.lasercyber.lws.ui.common.network.proxy.HttpProxySettingsStore;
import com.lasercyber.lws.ui.common.audio.MusicPlaybackVolume;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckSettings;
import com.lasercyber.lws.ui.common.constant.CommonSettingsLanguage;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.common.settings.SafetyGroundLockAlarmSettings;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.dialog.FrostDialog;
import com.lasercyber.lws.ui.component.dialog.NumberPickerUiUtils;
import com.lasercyber.lws.ui.databinding.FragmentCommonSettingsBinding;
import com.lasercyber.lws.ui.repository.CommonSettingsDao;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Locale;

/**
 * A composed Settings page for operator-facing common controls.
 */
public class CommonSettingsFragment extends BaseFragment<FragmentCommonSettingsBinding> {

    private static final String TAG = "CommonSettingsFragment";
    private static final long DEFAULT_SCREEN_OFF_TIMEOUT_MS = 10 * 60000;

    private CommonSettingsDao commonSettingsDao;
    private CommonSettings commonSettings;
    private HttpProxySettingsStore httpProxySettingsStore;
    private boolean suppressCallbacks = false;

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_common_settings;
    }

    @Override
    protected void initView() {
        commonSettingsDao = AppDatabase.getInstance(requireContext()).commonSettingsDao();
        httpProxySettingsStore = new HttpProxySettingsStore(requireContext());
        bindWirelessNetwork();
        bindHttpProxy();
        bindLanguage();
        bindUnit();
        bindBrightness();
        bindVolume();
        bindScreenOffTime();
        bindSoundEffect();
        bindAutomaticDateTime();
        bindDateTimeRows();
        bindBootSelfCheck();
        bindSafetyGroundLockAlarm();
        maybeAutoOpenWirelessNetwork();
    }

    @Override
    protected void initData() {
        ThreadPoolManager.getExecutor().execute(() -> {
            CommonSettings loaded = commonSettingsDao.selectOne();
            if (loaded == null) {
                loaded = DefaultValueUtils.createDefaultCommonSettings();
                long id = commonSettingsDao.insert(loaded);
                loaded.setId((int) id);
            }
            CommonSettings finalLoaded = loaded;
            new Handler(Looper.getMainLooper()).post(() -> {
                commonSettings = finalLoaded;
                renderCommonSettings();
            });
        });
        refreshWirelessNetwork();
        refreshHttpProxy();
        refreshBrightness();
        refreshVolume();
        refreshScreenOffTime();
        refreshDateTimeState();
    }

    @Override
    public void onResume() {
        super.onResume();
        refreshWirelessNetwork();
        refreshHttpProxy();
        refreshBrightness();
        refreshVolume();
        refreshScreenOffTime();
        refreshDateTimeState();
    }

    private void bindWirelessNetwork() {
        View.OnClickListener openWifi = v -> startActivity(new Intent(getContext(), WifiActivity.class));
        binding.wirelessNetworkInsetRow.setOnClickListener(openWifi);
    }

    private void bindHttpProxy() {
        binding.httpProxyInsetRow.setOnClickListener(v ->
                startActivity(new Intent(getContext(), HttpProxySettingsActivity.class)));
    }

    private void refreshHttpProxy() {
        if (binding == null || getContext() == null) {
            return;
        }
        HttpProxySettings settings = httpProxySettingsStore.load();
        if (!settings.enabled) {
            binding.httpProxyValue.setText(R.string.http_proxy_status_off);
            return;
        }
        if (settings.hasValidEndpoint()) {
            binding.httpProxyValue.setText(settings.host + ":" + settings.port);
        } else {
            binding.httpProxyValue.setText(R.string.http_proxy_status_incomplete);
        }
    }

    private void maybeAutoOpenWirelessNetwork() {
        Activity activity = getActivity();
        if (activity == null || activity.getIntent() == null) {
            return;
        }
        boolean shouldOpen = activity.getIntent()
                .getBooleanExtra(DeviceSettingActivity.EXTRA_OPEN_WIRELESS_NETWORK, false);
        if (!shouldOpen) {
            return;
        }
        activity.getIntent().putExtra(DeviceSettingActivity.EXTRA_OPEN_WIRELESS_NETWORK, false);
        startActivity(new Intent(getContext(), WifiActivity.class));
    }

    private void refreshWirelessNetwork() {
        if (binding == null || getContext() == null) {
            return;
        }
        String wifiName = SystemSettingUtils.getConnectedWifiName(requireContext());
        binding.wirelessNetworkValue.setText(wifiName == null || wifiName.isBlank()
                ? getString(R.string.not_connecting_text)
                : wifiName);
    }

    private void preserveSettingsTabBeforeLocaleChange() {
        Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        activity.getIntent().putExtra(
                DeviceSettingActivity.EXTRA_INITIAL_TAB_INDEX,
                DeviceSettingActivity.TAB_INDEX_COMMON_SETTINGS);
    }

    private void bindLanguage() {
        binding.languageSetting.setOnCheckedChangeListener((group, checkedId) -> {
            if (suppressCallbacks || commonSettings == null) {
                return;
            }
            String languageTag = checkedId == R.id.chinese
                    ? CommonSettingsLanguage.ZH_CN
                    : CommonSettingsLanguage.EN_US;
            if (languageTag.equals(CommonSettingsLanguage.fromLegacyLanguageSetting(commonSettings.getLanguage()))) {
                return;
            }
            commonSettings.setLanguage(languageTag);
            updateCommonSettings();
            preserveSettingsTabBeforeLocaleChange();
            try {
                LanguageUtils.applyLanguage(Locale.forLanguageTag(languageTag));
            } catch (Exception exception) {
                Log.w(TAG, "apply language failed", exception);
            }
        });
    }

    private void bindUnit() {
        binding.unitSetting.setOnCheckedChangeListener((group, checkedId) -> {
            if (suppressCallbacks || commonSettings == null) {
                return;
            }
            UnitSystem unitSystem = checkedId == R.id.unit_imperial
                    ? UnitSystem.IMPERIAL
                    : UnitSystem.METRIC;
            if (unitSystem == UnitSystem.fromWireValue(commonSettings.getUnit())) {
                return;
            }
            commonSettings.setUnit(unitSystem.getWireValue());
            updateCommonSettings();
        });
    }

    private void bindBrightness() {
        binding.seekBarScreenBrightness.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (!fromUser) {
                    return;
                }
                SystemSettingUtils.setSystemBrightness(getContext(), progress);
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
                GlobalSoundManager.playClickSound();
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
            }
        });
    }

    private void bindVolume() {
        binding.volumeControl.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (!fromUser || getContext() == null) {
                    return;
                }
                if (!MusicPlaybackVolume.setVolumePercent(requireContext(), progress)) {
                    ToastUtils.showShort(R.string.volume_set_failed);
                }
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
                GlobalSoundManager.playClickSound();
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
            }
        });
    }

    private void bindScreenOffTime() {
        binding.spinnerScreenOffTime.setOnCheckedChangeListener((group, checkedId) -> {
            if (suppressCallbacks) {
                return;
            }
            RadioButton checked = group.findViewById(checkedId);
            int index = group.indexOfChild(checked);
            int minutes = switch (index) {
                case 0 -> 10;
                case 1 -> 30;
                case 2 -> 60;
                default -> 120;
            };
            setScreenOffTimeoutMinutes(minutes);
        });
    }

    private void bindSoundEffect() {
        binding.spinnerScreenVoice.setOnCheckedChangeListener((group, checkedId) -> {
            if (suppressCallbacks || commonSettings == null) {
                return;
            }
            RadioButton checked = group.findViewById(checkedId);
            int index = group.indexOfChild(checked);
            if (index == (commonSettings.getSoundEffect() == null ? 0 : commonSettings.getSoundEffect())) {
                return;
            }
            commonSettings.setSoundEffect(index);
            GlobalSoundManager.openEffect(index, requireContext());
            updateCommonSettings();
        });
    }

    private void bindAutomaticDateTime() {
        binding.automaticSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressCallbacks || !buttonView.isPressed()) {
                return;
            }
            GlobalSoundManager.playClickSound();
            boolean timeUpdated = SystemSettingUtils.setAutoTimeEnabled(requireContext(), isChecked);
            boolean zoneUpdated = SystemSettingUtils.setAutoTimeZoneEnabled(requireContext(), isChecked);
            if (!timeUpdated || !zoneUpdated) {
                ToastUtils.showShort(R.string.date_time_permission_denied);
            }
            refreshDateTimeState();
        });
    }

    private void bindDateTimeRows() {
        binding.dateRow.setOnClickListener(v -> {
            if (SystemSettingUtils.isAutoTimeEnabled(requireContext())) {
                return;
            }
            showDatePicker();
        });
        binding.timeRow.setOnClickListener(v -> {
            if (SystemSettingUtils.isAutoTimeEnabled(requireContext())) {
                return;
            }
            showTimePicker();
        });
        binding.timeZoneRow.setOnClickListener(v -> {
            if (SystemSettingUtils.isAutoTimeZoneEnabled(requireContext())) {
                return;
            }
            showTimeZonePicker();
        });
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
                    if (!SystemSettingUtils.setDateAndTimeMillis(requireContext(), target.getTimeInMillis())) {
                        ToastUtils.showShort(R.string.date_time_set_failed);
                    }
                    refreshDateTimeState();
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
                    if (!SystemSettingUtils.setDateAndTimeMillis(requireContext(), target.getTimeInMillis())) {
                        ToastUtils.showShort(R.string.date_time_set_failed);
                    }
                    refreshDateTimeState();
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
                    refreshDateTimeState();
                })
                .show();
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

    private void bindBootSelfCheck() {
        binding.showBootSelfCheckSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressCallbacks || commonSettings == null) {
                return;
            }
            GlobalSoundManager.playClickSound();
            BootSelfCheckSettings.setEnabled(requireContext(), isChecked);
            commonSettings.setShowBootSelfCheck(isChecked);
            updateCommonSettings();
        });
    }

    private void bindSafetyGroundLockAlarm() {
        binding.showSafetyGroundLockAlarmSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressCallbacks || commonSettings == null) {
                return;
            }
            GlobalSoundManager.playClickSound();
            SafetyGroundLockAlarmSettings.setEnabled(requireContext(), isChecked);
            commonSettings.setShowSafetyGroundLockAlarm(isChecked);
            updateCommonSettings();
        });
    }

    private void renderCommonSettings() {
        if (binding == null || commonSettings == null) {
            return;
        }
        suppressCallbacks = true;
        String language = CommonSettingsLanguage.fromLegacyLanguageSetting(commonSettings.getLanguage());
        binding.languageSetting.check(CommonSettingsLanguage.isChinese(language) ? R.id.chinese : R.id.english);
        binding.unitSetting.check(UnitSystem.fromWireValue(commonSettings.getUnit()) == UnitSystem.IMPERIAL
                ? R.id.unit_imperial
                : R.id.unit_metric);
        int soundEffect = commonSettings.getSoundEffect() == null ? 0 : commonSettings.getSoundEffect();
        if (soundEffect == 1) {
            binding.spinnerScreenVoice.check(R.id.setting_effect2);
        } else if (soundEffect == 2) {
            binding.spinnerScreenVoice.check(R.id.setting_effect3);
        } else {
            binding.spinnerScreenVoice.check(R.id.setting_effect1);
        }
        binding.showBootSelfCheckSwitch.setChecked(
                commonSettings.getShowBootSelfCheck() == null || commonSettings.getShowBootSelfCheck());
        binding.showSafetyGroundLockAlarmSwitch.setChecked(
                Boolean.TRUE.equals(commonSettings.getShowSafetyGroundLockAlarm()));
        suppressCallbacks = false;
    }

    private void refreshBrightness() {
        if (binding == null || getContext() == null) {
            return;
        }
        binding.seekBarScreenBrightness.setProgress(SystemSettingUtils.getSystemBrightness(getContext()));
    }

    private void refreshVolume() {
        if (binding == null || getContext() == null) {
            return;
        }
        binding.volumeControl.setProgress(MusicPlaybackVolume.getVolumePercent(requireContext()));
    }

    private void refreshScreenOffTime() {
        if (binding == null || getContext() == null) {
            return;
        }
        long minutes = getScreenOffTimeoutMinutes();
        suppressCallbacks = true;
        if (minutes > 60) {
            binding.spinnerScreenOffTime.check(R.id.rb_never);
        } else if (minutes == 60) {
            binding.spinnerScreenOffTime.check(R.id.rb_60min);
        } else if (minutes == 30) {
            binding.spinnerScreenOffTime.check(R.id.rb_30min);
        } else {
            binding.spinnerScreenOffTime.check(R.id.rb_10min);
        }
        suppressCallbacks = false;
    }

    private long getScreenOffTimeoutMinutes() {
        try {
            long timeoutMs = Settings.System.getLong(
                    requireContext().getContentResolver(),
                    Settings.System.SCREEN_OFF_TIMEOUT,
                    DEFAULT_SCREEN_OFF_TIMEOUT_MS
            );
            return timeoutMs / 60000;
        } catch (Exception exception) {
            return DEFAULT_SCREEN_OFF_TIMEOUT_MS / 60000;
        }
    }

    private void setScreenOffTimeoutMinutes(int minutes) {
        try {
            Settings.System.putLong(
                    requireContext().getContentResolver(),
                    Settings.System.SCREEN_OFF_TIMEOUT,
                    minutes * 60000L
            );
        } catch (Exception exception) {
            Log.w(TAG, "set screen off timeout failed", exception);
        }
    }

    private void refreshDateTimeState() {
        if (binding == null || getContext() == null) {
            return;
        }
        Context context = requireContext();
        boolean autoTime = SystemSettingUtils.isAutoTimeEnabled(context);
        boolean autoTimeZone = SystemSettingUtils.isAutoTimeZoneEnabled(context);
        boolean automatic = autoTime && autoTimeZone;
        suppressCallbacks = true;
        binding.automaticSwitch.setChecked(automatic);
        suppressCallbacks = false;
        binding.dateRow.setEnabled(!autoTime);
        binding.timeRow.setEnabled(!autoTime);
        binding.timeZoneRow.setEnabled(!autoTimeZone);
        binding.dateArrow.setVisibility(autoTime ? View.GONE : View.VISIBLE);
        binding.timeArrow.setVisibility(autoTime ? View.GONE : View.VISIBLE);
        binding.timeZoneArrow.setVisibility(autoTimeZone ? View.GONE : View.VISIBLE);
        binding.dateValue.setText(formatDate(System.currentTimeMillis()));
        binding.timeValue.setText(formatTime(System.currentTimeMillis()));
        binding.timeZoneValue.setText(SystemSettingUtils.getCurrentTimeZoneId());
        if (!autoTime && !autoTimeZone) {
            binding.autoSyncStatus.setText(R.string.date_time_auto_sync_off);
        } else if (!SystemSettingUtils.isNetworkConnected(context)) {
            binding.autoSyncStatus.setText(R.string.date_time_auto_sync_offline);
        } else {
            binding.autoSyncStatus.setText(R.string.date_time_auto_syncing);
        }
    }

    private void updateCommonSettings() {
        CommonSettings snapshot = commonSettings;
        if (snapshot == null) {
            return;
        }
        ThreadPoolManager.getExecutor().execute(() -> commonSettingsDao.update(snapshot));
    }

    private static String formatDate(long millis) {
        return new SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(millis);
    }

    private static String formatTime(long millis) {
        return new SimpleDateFormat("HH:mm", Locale.getDefault()).format(millis);
    }
}
