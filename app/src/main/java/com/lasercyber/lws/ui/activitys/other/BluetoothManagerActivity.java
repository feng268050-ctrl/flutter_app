package com.lasercyber.lws.ui.activitys.other;

import static com.lasercyber.lws.ui.common.modbus.call.ModbusLogger.TAG;
import static com.xuexiang.xutil.XUtil.getContext;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothSocket;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Build;
import android.util.Log;
import android.view.View;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.annotation.RequiresPermission;
import androidx.core.app.ActivityCompat;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.blankj.utilcode.util.PermissionUtils;
import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.MainActivity;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.activitys.other.adapter.BluetoothDeviceAdapter;
import com.lasercyber.lws.ui.bean.entity.BluetoothDeviceModel;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.ClickLook;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.EquipmentStatusBar;
import com.lasercyber.lws.ui.databinding.ActivityBluetoothBinding;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

public class BluetoothManagerActivity extends BaseActivity<ActivityBluetoothBinding> {
    private BluetoothAdapter bluetoothAdapter;
    private RecyclerView rvBluetoothDevices;
    private BluetoothDeviceAdapter deviceAdapter;
    // 蓝牙Socket和读写流
    private BluetoothSocket bluetoothSocket;
    private List<BluetoothDeviceModel> deviceList = new ArrayList<>();
    // 2. 标记位：记录接收器是否已注册
    private boolean isReceiverRegistered = false;

    private ClickLook look = new ClickLook();

    // 开启蓝牙请求Launcher
    private final ActivityResultLauncher<Intent> enableBtLauncher = registerForActivityResult(
        new ActivityResultContracts.StartActivityForResult(),
        result -> {
            if (result.getResultCode() == RESULT_OK) {
                startScanDevices();
            }
        }
    );

    // 蓝牙广播接收器
    private final BroadcastReceiver bluetoothReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            if (action == null) return;

            switch (action) {
                // 发现新设备
                case BluetoothDevice.ACTION_FOUND:
                    handleDeviceFound(intent);
                    break;
                // 配对状态变化
                case BluetoothDevice.ACTION_BOND_STATE_CHANGED:
                    handleBondStateChange(intent);
                    break;
                // 连接状态变化
                case BluetoothDevice.ACTION_ACL_CONNECTED:
                    handleConnectStateChange(intent, true);
                    break;
                case BluetoothDevice.ACTION_ACL_DISCONNECTED:
                    handleConnectStateChange(intent, false);
                    break;
            }
        }
    };

    @Override
    protected void initView() {
        //跳转首页
        toHomePage();
        //跳转上一页
        goToUpPage();
        // 初始化RecyclerView
        rvBluetoothDevices = findViewById(R.id.rv_bluetooth_devices);
        rvBluetoothDevices.setLayoutManager(new LinearLayoutManager(this));
        deviceAdapter = new BluetoothDeviceAdapter(deviceList,this::pairDevice);
        rvBluetoothDevices.setAdapter(deviceAdapter);

        binding.bluetoothCon.setVisibility(View.GONE);
        binding.bluetoothConNot.setVisibility(View.VISIBLE);

        boolean bluetoothEnabled = SystemSettingUtils.isBluetoothEnabled();
        if( bluetoothEnabled ){
            //申请权限
            requestBluetoothPermissions();
        }else {
            binding.bluetoothSwitch.setChecked(false);
        }
        //开关蓝牙
        openAndOff();
    }

    //获取之间连接过的蓝牙设备
    private void getLineDevice(){
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {}
        Set<BluetoothDevice> bondedDevices = bluetoothAdapter.getBondedDevices();
        for (BluetoothDevice device : bondedDevices) {
            BluetoothDeviceModel deviceModel = new BluetoothDeviceModel(
                    device.getName(),
                    device.getAddress(),
                    false,
                    device.getBondState() == BluetoothDevice.BOND_BONDED
            );
            // 避免重复添加同一设备
            if (!deviceList.contains(deviceModel)) {
                deviceList.add(deviceModel);
                deviceAdapter.notifyItemInserted(deviceList.size() - 1);
            }
        }

    }

    //开关蓝牙
    private void openAndOff(){
        // 开关监听：控制蓝牙开启/关闭
        binding.bluetoothSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            GlobalSoundManager.playClickSound();
            if (isChecked) {
                requestBluetoothPermissions();
            }else{
                deviceAdapter.updateDevices(deviceList);
                binding.bluetoothCon.setVisibility(View.GONE);
                binding.bluetoothConNot.setVisibility(View.VISIBLE);

                binding.bluetoothConNotText.setText("Bluetooth is not enabled.");
                binding.bluetoothConNotText.setTextColor(Color.parseColor("#909399"));

                if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {}
                bluetoothAdapter.disable();
            }
        });
    }
    // 申请所需蓝牙权限
    private void requestBluetoothPermissions() {
        List<String> permissions = new ArrayList<>();
        // Android 12+ 蓝牙权限
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN);
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
        } else {
            // Android 6.0+ 位置权限
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION);
            permissions.add(Manifest.permission.BLUETOOTH);
            permissions.add(Manifest.permission.BLUETOOTH_ADMIN);
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
            permissions.add(Manifest.permission.BLUETOOTH_SCAN);
            permissions.add(Manifest.permission.BLUETOOTH_ADVERTISE);
            permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION);

        }
        PermissionUtils.permission(permissions.toArray(new String[]{})).callback(new PermissionUtils.FullCallback() {
            @Override
            public void onGranted(@NonNull List<String> granted) {
                Log.d(TAG, "onGranted: 通过:"+granted);
                if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {}
                initBluetooth();
                //获取之前连接过的蓝牙
                getLineDevice();
                // 初始化开关状态
                binding.bluetoothSwitch.setChecked(bluetoothAdapter.isEnabled());
            }

            @Override
            public void onDenied(@NonNull List<String> deniedForever, @NonNull List<String> denied) {
            }
        }).request();
    }

    // 初始化蓝牙适配器
    @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
    private void initBluetooth() {
        BluetoothManager bluetoothManager = (BluetoothManager) getSystemService(BLUETOOTH_SERVICE);
        bluetoothAdapter = bluetoothManager.getAdapter();

        if (bluetoothAdapter == null) {
            finish();
            return;
        }

        // 注册广播接收器
        registerBluetoothReceiver();

        // 检查蓝牙是否开启
        if (!bluetoothAdapter.isEnabled()) {
            Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
            enableBtLauncher.launch(enableBtIntent);
        } else {
            startScanDevices();
        }
    }

    // 注册蓝牙相关广播
    private void registerBluetoothReceiver() {
        if(isReceiverRegistered) {return;}
        IntentFilter filter = new IntentFilter();
        filter.addAction(BluetoothDevice.ACTION_FOUND);
        filter.addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED);
        filter.addAction(BluetoothDevice.ACTION_ACL_CONNECTED);
        filter.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED);
        registerReceiver(bluetoothReceiver, filter);
        isReceiverRegistered = true;
    }

    // 开始扫描蓝牙设备
    private void startScanDevices() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADMIN) != PackageManager.PERMISSION_GRANTED) {return;}
        if (bluetoothAdapter.isDiscovering()) bluetoothAdapter.cancelDiscovery();
        boolean b = bluetoothAdapter.startDiscovery();
        if(b){
            binding.bluetoothConNotText.setText("During Bluetooth search ...");
            binding.bluetoothConNotText.setTextColor(Color.parseColor("#00BF60"));
        }
        binding.bluetoothSwitch.setChecked(bluetoothAdapter.isEnabled());
    }

    // 处理“发现新设备”广播
    private void handleDeviceFound(Intent intent) {
        BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
        if (device == null) return;

        // 构造设备模型（初始状态：未连接，配对状态由系统BondState决定）
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {}

        String name = device.getName();
        if( name == null || StringUtils.isEmpty( name )){
            return;
        }

        BluetoothDeviceModel deviceModel = new BluetoothDeviceModel(
                device.getName(),
                device.getAddress(),
                false,
                device.getBondState() == BluetoothDevice.BOND_BONDED
        );

        // 避免重复添加同一设备
        if (!deviceList.contains(deviceModel)) {
            deviceList.add(deviceModel);
            deviceAdapter.notifyItemInserted(deviceList.size() - 1);
        }
    }

    // 处理“配对状态变化”广播
    private void handleBondStateChange(Intent intent) {
        BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
        if (device == null) return;

        int newBondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE);
        boolean isPaired = newBondState == BluetoothDevice.BOND_BONDED;

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
            return;
        }
        // 更新设备配对状态
        BluetoothDeviceModel updatedDevice = new BluetoothDeviceModel(
                device.getName(),
                device.getAddress(),
                false, // 连接状态暂不修改
                isPaired
        );
        deviceAdapter.updateDeviceStatus(updatedDevice);
    }

    // 处理“连接状态变化”广播
    private void handleConnectStateChange(Intent intent, boolean isConnected) {
        BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
        if (device == null) return;

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {}

        String name = device.getName();
        if( name == null || StringUtils.isEmpty( name )){
            return;
        }
        // 更新设备连接状态
        BluetoothDeviceModel updatedDevice = new BluetoothDeviceModel(
                device.getName(),
                device.getAddress(),
                isConnected,
                device.getBondState() == BluetoothDevice.BOND_BONDED
        );
        deviceAdapter.updateDeviceStatus(updatedDevice);
    }

    // 点击设备项：触发配对
    private void pairDevice(BluetoothDeviceModel device,Boolean isClose) {
        GlobalSoundManager.playClickSound();

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {}
        // 获取系统蓝牙设备对象
        BluetoothDevice bluetoothDevice = bluetoothAdapter.getRemoteDevice(device.getDeviceAddress());
        // 未配对则发起配对请求
        int bondState = bluetoothDevice.getBondState();
        if (bondState != BluetoothDevice.BOND_BONDED) {
            bluetoothDevice.createBond();
            return;
        }

        /*如果已连接，则建立链接*/
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                // 前置：取消蓝牙扫描（释放资源）
                if (bluetoothAdapter.isDiscovering()) {
                    bluetoothAdapter.cancelDiscovery();
                }
                // 创建RFCOMM Socket（基于通用UUID）
                bluetoothSocket = createRfcommSocket(bluetoothDevice);

                // 步骤5：建立连接（阻塞方法）
                bluetoothSocket.connect();

                // 连接成功：后续逻辑（如获取读写流）
                handler.post(() -> ToastUtils.showShort(R.string.connection_successful));
                InputStream inputStream = bluetoothSocket.getInputStream();
                OutputStream outputStream = bluetoothSocket.getOutputStream();
            } catch (Exception e) {
                Log.e(TAG, "pairDevice: 连接失败",e );
                // 连接失败：释放资源+主线程反馈
                handler.post(this::releaseBluetoothResources);
            }
        });
    }

    // 新增：反射创建RFCOMM Socket的核心方法（替代原生createRfcommSocketToServiceRecord）
    private BluetoothSocket createRfcommSocket(BluetoothDevice device) throws Exception {
        // 反射调用BluetoothDevice的隐藏方法：createRfcommSocket(int channel)
        // 通道1是蓝牙SPP串口协议的默认通道，几乎所有蓝牙设备都支持
        Method createRfcommSocketMethod = device.getClass().getMethod("createRfcommSocket", int.class);
        return (BluetoothSocket) createRfcommSocketMethod.invoke(device, 1);
    }

    /**
     * 释放蓝牙资源（断开连接、关闭流和Socket）
     */
    private void releaseBluetoothResources() {
        try {
            if (bluetoothSocket != null) bluetoothSocket.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
        // 置空资源，避免空指针
        bluetoothSocket = null;
    }


    @Override
    protected void initData() {
    }

    @Override
    protected int getLayoutId() {
        return R.layout.activity_bluetooth;
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        // 停止扫描+注销广播
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {}

        if (bluetoothAdapter != null && bluetoothAdapter.isDiscovering()) {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADMIN) == PackageManager.PERMISSION_GRANTED) {
                bluetoothAdapter.cancelDiscovery();
            }
        }

        try {
            if(isReceiverRegistered) unregisterReceiver(bluetoothReceiver);
            if (bluetoothSocket != null) bluetoothSocket.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
        // 置空资源，避免空指针
        bluetoothSocket = null;
    }


    //跳转上一页
    private void goToUpPage(){
        binding.goToUpPage.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                GlobalSoundManager.playClickSound();
                finish();
            }
        });
    }

    private void toHomePage(){
        //直接跳转到首页
        binding.engineerEquipmentStatus.setOnCallBackListener(new EquipmentStatusBar.OnCallBackListener() {
            @Override
            public void onCallBack() {
                Intent intent = new Intent(getContext(), MainActivity.class);
                // 核心：复用目标Activity，清除其上方的所有Activity
                intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                startActivity(intent);
                // 可选：销毁当前Activity
                finish();
            }
        });
    }


}

