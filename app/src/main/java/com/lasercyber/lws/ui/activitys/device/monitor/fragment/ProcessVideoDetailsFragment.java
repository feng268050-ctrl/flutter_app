package com.lasercyber.lws.ui.activitys.device.monitor.fragment;

import android.util.Log;

import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.device.monitor.model.ProcessVideoDetailsViewModel;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.databinding.FragmentProcessVideoDetailsBinding;

import lombok.Setter;

/**
 * A simple {@link Fragment} subclass.
 * Use the {@link ProcessVideoDetailsFragment#newInstance} factory method to
 * create an instance of this fragment.
 */
@Deprecated
public class ProcessVideoDetailsFragment extends BaseFragment<FragmentProcessVideoDetailsBinding> {
    private static final String TAG = LogTAGConstant.ProcessVideoDetailsFragment;
    @Setter
    private PageSwitchListener pageSwitchListener;
    @Setter
    private long processVideoId;
    private ProcessVideoDetailsViewModel processVideoViewModel;

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_process_video_details;
    }

    @Override
    protected void initView() {
        Log.d(TAG, "initView: 正在初始化视图:" + processVideoId);
        processVideoViewModel = new ViewModelProvider(this).get(ProcessVideoDetailsViewModel.class);
        processVideoViewModel.init(getContext(), processVideoId);

    }

    @Override
    protected void initData() {

    }

    @Override
    protected void bindViewModel() {
        super.bindViewModel();
        binding.callBackPreviousPage.setOnClickListener(v -> {
            if (pageSwitchListener != null) {
                pageSwitchListener.previousPage();
            }
        });
        binding.setProcessVideoDetailsViewModel(processVideoViewModel);
    }

    @Override
    public long fragmentId() {
        return 200000;
    }

    public interface PageSwitchListener {
        void previousPage();
    }
}