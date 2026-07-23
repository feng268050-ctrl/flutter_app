package com.lasercyber.lws.ui.common.upgrade;

import android.util.Log;

import com.lasercyber.lws.ui.common.handler.ControllerUpgradeHandler;

import java.io.File;

public class BinUtil {

    public static void binFileConvert(File file) {
        binFileConvert(file, false);
    }

    public static void binFileConvert(File file, boolean skipSameVersionCheck) {
        ControllerUpgradeHandler.sendControllerUpgradeInfo(file, skipSameVersionCheck);
    }

}
