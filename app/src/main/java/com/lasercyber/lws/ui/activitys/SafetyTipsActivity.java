package com.lasercyber.lws.ui.activitys;

import android.content.Intent;
import android.view.View;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.MainActivity;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.utils.StoragePermissionHelper;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.databinding.ActivitySafetyTipsBinding;

public class SafetyTipsActivity extends BaseActivity<ActivitySafetyTipsBinding> {

    private final ActivityResultLauncher<String[]> requestVideoReadForLws =
            registerForActivityResult(new ActivityResultContracts.RequestMultiplePermissions(), granted -> {
                if (StoragePermissionHelper.allGranted(granted)) {
                    navigateToMain();
                } else {
                    ToastUtils.showShort(R.string.lws_video_storage_permission_required);
                }
            });

    @Override
    protected void initView() {
        /*中英文适配*/
        String tltle = getResources().getString(R.string.safety_tips_title);
        binding.title.setText(tltle);

        String content = getResources().getString(R.string.safety_tips_content);
        binding.content.setText(content);

        String info = getResources().getString(R.string.safety_tips_info);
        binding.cbAgree.setLabelText(info);

        String infoUse = getResources().getString(R.string.safety_tips_info_use);

        binding.infoUse.setText(" “"+infoUse+"”");

        String agree = getResources().getString(R.string.safety_tips_agree);
        binding.btnAgree.setText(agree);

        syncAgreeButton(binding.cbAgree.isChecked());
        binding.cbAgree.setOnCheckedChangeListener((checkbox, isChecked) -> {
            GlobalSoundManager.playClickSound();
            syncAgreeButton(isChecked);
        });
    }

    private void syncAgreeButton(boolean checked) {
        binding.btnAgree.setEnabled(checked);
    }

    public void toHome(View view) {
        GlobalSoundManager.playClickSound();
        if (!binding.cbAgree.isChecked()) {
            return;
        }
        if (!StoragePermissionHelper.shouldRequestRuntimeVideoRead(this)) {
            navigateToMain();
            return;
        }
        requestVideoReadForLws.launch(StoragePermissionHelper.videoReadPermissions());
    }

    private void navigateToMain() {
        startActivity(new Intent(this, MainActivity.class));
        finish();
    }

    public void toInfoUse(View view){
        GlobalSoundManager.playClickSound();
        Intent intent = new Intent(this, UseSafetyTipsActivity.class);
        startActivity(intent);
    }

    @Override
    protected void initData() {

    }

    @Override
    protected int getLayoutId() {
        return R.layout.activity_safety_tips;
    }
}
