package com.lasercyber.lws.ui.activitys;

import android.view.View;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.databinding.ActivityUseSafetyTipsBinding;

public class UseSafetyTipsActivity extends BaseActivity<ActivityUseSafetyTipsBinding> {
    @Override
    protected void initView() {
        /*中英文适配*/
        String tltle = getResources().getString(R.string.use_safety_tips_title);
        binding.title.setText(tltle);

        String content = getResources().getString(R.string.use_safety_tips_content);
        binding.content.setText(content);

        String info = getResources().getString(R.string.use_safety_tips_info);
        binding.cbAgree.setLabelText(info);

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
        if (binding.cbAgree.isChecked()) {
            finish();
        }
    }


    @Override
    protected void initData() {

    }

    @Override
    protected int getLayoutId() {
        return R.layout.activity_use_safety_tips;
    }
}
