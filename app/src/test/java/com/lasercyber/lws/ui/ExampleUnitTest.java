package com.lasercyber.lws.ui;

import static org.junit.Assert.assertEquals;

import com.lasercyber.lws.ui.bean.test.DeviceHexSample;
import com.lasercyber.lws.ui.bean.test.DeviceHexTest;
import com.lasercyber.lws.ui.bean.test.User;
import com.lasercyber.lws.ui.common.utils.bit.LongBitReaderUtils;
import com.lasercyber.lws.ui.common.utils.hex.HexDataContent;
import com.lasercyber.lws.ui.common.utils.hex.HexDataConvert;

import org.junit.Test;

import java.util.Arrays;
import java.util.List;

/**
 * Example local unit test, which will execute on the development machine (host).
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
public class ExampleUnitTest {
    @Test
    public void addition_isCorrect() {
        assertEquals(4, 2 + 2);
    }

    @Test
    public void hexDataConvertTest() {
        DeviceHexSample deviceTest = new DeviceHexSample();
        deviceTest.ctrBoardNo = 1;
        deviceTest.ctrPortNo = 1;
        deviceTest.devType = 1;
        deviceTest.devName = "测试设备";
        deviceTest.spdEn = 1;
        deviceTest.pwrChkEn = 1;
        deviceTest.pwrLimit = 1;
        deviceTest.runModelType = 1;
        deviceTest.portEnable = 1;
        String hexData = HexDataConvert.convertToHexData(deviceTest);
        System.out.println(hexData);
        DeviceHexSample convertDeviceTest = HexDataConvert.convertToObject(hexData, new DeviceHexSample());
        System.out.println(convertDeviceTest);
    }

    @Test
    public void getFiledTest() {
        DeviceHexTest deviceTest = new DeviceHexTest();
        deviceTest.ctrBoardNo = 1;
        deviceTest.ctrPortNo = 1;
        deviceTest.devType = 1;
        deviceTest.devName = "测试设备";
        deviceTest.spdEn = 1;
        deviceTest.pwrChkEn = 1;
        deviceTest.pwrLimit = 1;
        deviceTest.runModelType = 1;
        deviceTest.portEnable = 1;
        User user = new User();
        user.userName = "测试用户";
        user.age = 18;
        deviceTest.userList = List.of(user);
        List<HexDataContent> filedList = HexDataConvert.createFiledList(deviceTest);
        System.out.println(filedList);
        String hexData = HexDataConvert.fileListConvertToHexData(filedList);
        System.out.println(hexData);
        DeviceHexTest convertDeviceTest = new DeviceHexTest();
        convertDeviceTest.userList = List.of(new User());
        DeviceHexTest deviceHexTest = HexDataConvert.convertToObject(hexData, convertDeviceTest);
        System.out.println(deviceHexTest);
    }

    @Test
    public void mmTest() {
        System.out.println(Arrays.toString(LongBitReaderUtils.readBitsAll(17)));
    }
}
