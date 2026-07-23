package com.lasercyber.lws.ui.activitys.device.monitor.fragment;

import android.view.View;

import androidx.fragment.app.Fragment;
import androidx.lifecycle.MutableLiveData;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.WarnTableViewModel;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.bean.event.WarnLogChangedEvent;
import com.lasercyber.lws.ui.bean.entity.vo.WarnTableVo;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.WarnTableCallBack;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.adapter.WarnLogAdapter;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;
import com.lasercyber.lws.ui.databinding.FragmentWarnLogBinding;

import java.util.ArrayList;
import java.util.List;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

/**
 * A simple {@link Fragment} subclass.
 * create an instance of this fragment.
 * 告警日志
 */
public class WarnLogFragment extends BaseFragment<FragmentWarnLogBinding> {
    private WarnLogAdapter adapter;
    private WarnTableVo warnTableVo;
    private WarnTableViewModel warnTableViewModel;
    private LinearLayoutManager layoutManager;
    // 防抖核心：加载中标志位
    private boolean isLoading = false;
    /** 用户点击清除后，等待 {@link WarnLogChangedEvent.Kind#CLEARED} 再提示成功。 */
    private boolean pendingClearFeedback = false;


    /*增加页面事件*/
    @Override
    protected void initView() {
        binding.btnClear.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                GlobalSoundManager.playClickSound();
                if (pendingClearFeedback) {
                    return;
                }
                pendingClearFeedback = true;
                // 清除按钮，一键删除故障记录；UI 与成功提示由 WarnLogChangedEvent 驱动
                warnTableViewModel.deleteAll(getContext());
            }
        });
    }

    /*操作列表，触底事件*/
    private void operationTableBottom(LinearLayoutManager layoutManager){
        binding.rvWarnLogs.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrolled(RecyclerView recyclerView, int dx, int dy) {
                super.onScrolled(recyclerView, dx, dy);
                // 仅处理“向上滚动”（dy>0）的情况
                if (dy <= 0) return;

                // 获取总数据项数
                int totalItemCount = layoutManager.getItemCount();
                // 获取最后一个可见项的位置
                int lastVisibleItemPosition = layoutManager.findLastVisibleItemPosition();

                // 触底条件：最后一个可见项是最后一项 + 不在加载中
                if (lastVisibleItemPosition == totalItemCount - 1  && !isLoading) {
                    onBottomReached( totalItemCount ); // 触发触底逻辑
                }
            }
        });
    }
    //触底触发
    private void onBottomReached( int number ){
        // 1. 防抖：标记为“加载中”
        isLoading = true;
        //通过回调，加载数据
        warnTableViewModel.getPageContent(number, getContext(), new WarnTableCallBack() {
            @Override
            public void getTableList(List<WarnTable> list) {
                if (CollUtil.isEmpty(list)) {
                    isLoading = false;
                    return;
                }
                adapter.addMoreLogs(list);
                isLoading = false;
            }
        });
    }
    /*1、进行添加模拟数据
      2、进行查询展示
      3、进行分页查询
    * */
    @Override
    protected void initData() {
        if (!EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().register(this);
        }

        //查询告警记录
        warnTableViewModel = new ViewModelProvider(this).get(WarnTableViewModel.class);
        warnTableViewModel.init( getContext() );
        MutableLiveData<WarnTableVo> liveData = warnTableViewModel.getLiveData();

        liveData.observe(this, item -> {
            if (item == null) {
                return;
            }
            warnTableVo = new WarnTableVo();
            warnTableVo.setPage(item.getPage());
            warnTableVo.setNumber(item.getNumber());
            List<WarnTable> list = new ArrayList<>();
            if (item.getListData() != null && !item.getListData().isEmpty()) {
                for (WarnTable listDatum : item.getListData()) {
                    String content = listDatum.getContent();
                    if (StrUtil.isBlank(content)) {
                        int titleId = AlarmCodeEnums.findTitleId(listDatum.getCode());
                        if (titleId <= 0) {
                            titleId = R.string.def_warn_text;
                        }
                        content = getString(titleId);
                    }
                    list.add(new WarnTable(listDatum.getYmdDate(),
                            listDatum.getHmDate(),
                            listDatum.getCode(),
                            content,
                            listDatum.getTime(),
                            listDatum.getNewTime()));
                }
            }
            warnTableVo.setListData(list);

            if (adapter == null) {
                adapter = new WarnLogAdapter(warnTableVo);
                binding.rvWarnLogs.setAdapter(adapter);
                layoutManager = new LinearLayoutManager(getContext());
                layoutManager.setOrientation(LinearLayoutManager.VERTICAL);
                binding.rvWarnLogs.setLayoutManager(layoutManager);
                binding.rvWarnLogs.setHasFixedSize(true);
                operationTableBottom(layoutManager);
            } else {
                adapter.setWarnLogs(list);
            }
        });
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onWarnLogChanged(WarnLogChangedEvent event) {
        if (warnTableViewModel == null || getContext() == null) {
            return;
        }
        if (event.getKind() == WarnLogChangedEvent.Kind.CLEARED && adapter != null) {
            adapter.clearLogs();
            if (pendingClearFeedback) {
                pendingClearFeedback = false;
                GlobalDialogUtil.showStatusDialog(
                        getContext(),
                        1,
                        getString(R.string.warn_log_clear_success),
                        getResources().getString(R.string.complete_operation));
            }
            return;
        }
        warnTableViewModel.init(getContext());
    }

    @Override
    public void onDestroyView() {
        pendingClearFeedback = false;
        if (EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().unregister(this);
        }
        super.onDestroyView();
    }

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_warn_log;
    }
}
