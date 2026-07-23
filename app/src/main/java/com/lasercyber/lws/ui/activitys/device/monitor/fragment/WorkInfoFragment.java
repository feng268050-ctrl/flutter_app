package com.lasercyber.lws.ui.activitys.device.monitor.fragment;

import android.content.Context;
import android.graphics.Color;
import android.graphics.Rect;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.MutableLiveData;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.StaticDataViewModel;
import com.lasercyber.lws.ui.bean.entity.Home;
import com.lasercyber.lws.ui.bean.entity.HomeStatic;
import com.lasercyber.lws.ui.bean.entity.StaticData;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.common.utils.bean.StatItem;
import com.lasercyber.lws.ui.component.adapter.StatAdapter;
import com.lasercyber.lws.ui.databinding.FragmentWorkInfoBinding;
import com.lasercyber.lws.ui.page.HomePage;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import cn.hutool.core.util.ObjectUtil;

/**
 * A simple {@link Fragment} subclass.
 * create an instance of this fragment.
 * 工作信息
 */
public class WorkInfoFragment extends BaseFragment<FragmentWorkInfoBinding> {
    private static final String TAG = LogTAGConstant.WorkInfoFragment;

    private StaticDataViewModel staticDataViewModel;

    private StatAdapter adapter;
    private List<StatItem> itemList;

    private Context context;
    private HomePage homePage;
    private StaticData lastStaticData;
    private String displayUnitWireValue = UnitSystem.METRIC.getWireValue();

    public WorkInfoFragment(Context context){
         this.context = context;
    }


    @Override
    protected int getLayoutId() {
        return R.layout.fragment_work_info;
    }

    @Override
    protected void initData() {
        homePage = new HomePage(getContext());
        AppDatabase.getInstance(requireContext()).commonSettingsDao().selectOneLiveData()
                .observe(this, settings -> {
                    String unit = settings != null && settings.getUnit() != null
                            ? settings.getUnit()
                            : UnitSystem.METRIC.getWireValue();
                    if (Objects.equals(displayUnitWireValue, unit)) {
                        return;
                    }
                    displayUnitWireValue = unit;
                    if (isResumed()) {
                        refreshWorkInfoStats();
                    }
                });
        staticDataViewModel = new ViewModelProvider(this).get(StaticDataViewModel.class);
        staticDataViewModel.initMutableLiveData(getContext());
        MutableLiveData<StaticData> liveData = staticDataViewModel.getLiveData();

        liveData.observe(this, item -> {
            if (ObjectUtil.isNull(item)) {
                return;
            }
            lastStaticData = item;
            if (isResumed()) {
                refreshWorkInfoStats();
            }
        });
    }

    @Override
    public void onResume() {
        super.onResume();
        if (lastStaticData != null) {
            refreshWorkInfoStats();
        }
    }

    private void refreshWorkInfoStats() {
        if (lastStaticData == null) {
            return;
        }
        Home data = homePage.setPageDataToHome(lastStaticData, displayUnitWireValue);
        initCharConfig(data);
    }

    /**
     * 初始化图表
     */
    public void initCharConfig(Home data) {
        if (binding.recyclerView.getLayoutManager() == null) {
            binding.recyclerView.setLayoutManager(new GridLayoutManager(context, 3));
        }
        ensureGridSpacingDecoration();
        List<HomeStatic> list = data.getList();
        if (itemList == null) {
            itemList = new ArrayList<>();
        } else {
            itemList.clear();
        }
        itemList.add(new StatItem(StatItem.TYPE_RING, list.get(5).getStaticTitle(), list.get(5).getStaticNumber(), list.get(5).getStaticInfo(), Color.parseColor("#FF0000")));
        itemList.add(new StatItem(StatItem.TYPE_RING, list.get(4).getStaticTitle(), list.get(4).getStaticNumber(), list.get(4).getStaticInfo(), Color.parseColor("#00A4F2")));
        itemList.add(new StatItem(StatItem.TYPE_RING, list.get(3).getStaticTitle(), list.get(3).getStaticNumber(), list.get(3).getStaticInfo(), Color.parseColor("#FF8000")));
        itemList.add(new StatItem(StatItem.TYPE_DATA, list.get(0).getStaticTitle(), list.get(0).getStaticNumber(), list.get(0).getStaticInfo()));
        itemList.add(new StatItem(StatItem.TYPE_DATA, list.get(1).getStaticTitle(), list.get(1).getStaticNumber(), list.get(1).getStaticInfo()));
        itemList.add(new StatItem(StatItem.TYPE_DATA, list.get(2).getStaticTitle(), list.get(2).getStaticNumber(), list.get(2).getStaticInfo()));

        if (adapter == null) {
            adapter = new StatAdapter(context, itemList);
            binding.recyclerView.setAdapter(adapter);
        } else {
            adapter.notifyDataSetChanged();
        }
    }


    public void initView() {
    }

    private void ensureGridSpacingDecoration() {
        RecyclerView recyclerView = binding.recyclerView;
        if (recyclerView.getItemDecorationCount() > 0) {
            return;
        }
        final int spanCount = 3;
        final int spacing = getResources().getDimensionPixelSize(R.dimen.frost_dialog_content_padding);
        recyclerView.addItemDecoration(new RecyclerView.ItemDecoration() {
            @Override
            public void getItemOffsets(
                    @NonNull Rect outRect,
                    @NonNull View view,
                    @NonNull RecyclerView parent,
                    @NonNull RecyclerView.State state) {
                int position = parent.getChildAdapterPosition(view);
                if (position == RecyclerView.NO_POSITION) {
                    return;
                }
                int column = position % spanCount;
                outRect.left = column * spacing / spanCount;
                outRect.right = spacing - (column + 1) * spacing / spanCount;
                if (position >= spanCount) {
                    outRect.top = spacing;
                }
            }
        });
    }
}
