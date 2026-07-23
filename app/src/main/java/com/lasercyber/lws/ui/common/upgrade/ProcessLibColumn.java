package com.lasercyber.lws.ui.common.upgrade;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.utils.convert.ProcessDataExcelConvert;

/**
 * Canonical headers for 工艺库_V*.xlsx (see process-lib-xlsx-import spec) bound to {@link ProcessParametersData}.
 */
enum ProcessLibColumn {

    PARAMS_NAME("参数名称") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setName(ProcessLibRowMapper.nullIfEmptyString(cell));
        }
    },
    MATERIALS("材料") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            String s = ProcessLibRowMapper.nullIfEmptyString(cell);
            if (s == null) {
                p.setMaterialType(null);
            } else {
                p.setMaterialType(ProcessDataExcelConvert.convertMaterials(s));
            }
        }
    },
    MATERIALS_NAME("材质名称") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setMaterialName(ProcessLibRowMapper.nullIfEmptyString(cell));
        }
    },
    THICKNESS("厚度") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setThickness(ProcessLibRowMapper.nullIfEmptyDouble(cell));
        }
    },
    LASER_POWER("激光功率") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setLaserPower(ProcessLibRowMapper.nullIfEmptyInteger(cell));
        }
    },
    SWING_FREQUENCY("摆动频率") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setSwingFrequency(ProcessLibRowMapper.nullIfEmptyInteger(cell));
        }
    },
    SWING_WIDTH("摆动宽度") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setSwingWidth(ProcessLibRowMapper.nullIfEmptyDouble(cell));
        }
    },
    BLOW_DELAY("吹气延时") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setBlowDelay(ProcessLibRowMapper.nullIfEmptyInteger(cell));
        }
    },
    CLOSE_AIR_DELAY("关气延时") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setCloseAirDelay(ProcessLibRowMapper.nullIfEmptyInteger(cell));
        }
    },
    CLOSE_LIGHT_DELAY("关光延时") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setCloseLightDelay(ProcessLibRowMapper.nullIfEmptyInteger(cell));
        }
    },
    FILL_DELAY("补丝时延") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setFillDelay(ProcessLibRowMapper.nullIfEmptyInteger(cell));
        }
    },
    POINT_WELDING_INTERVAL("点焊间隔") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setPointWeldingInterval(ProcessLibRowMapper.nullIfEmptyInteger(cell));
        }
    },
    POINT_WELDING_DURATION("点焊持续") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setPointWeldingDuration(ProcessLibRowMapper.nullIfEmptyInteger(cell));
        }
    },
    POWER_RAMP_UP("功率缓升") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setPowerRampUp(ProcessLibRowMapper.nullIfEmptyInteger(cell));
        }
    },
    POWER_RAMP_DOWN("功率缓降") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setPowerRampDown(ProcessLibRowMapper.nullIfEmptyInteger(cell));
        }
    },
    WIRE_FEED_SPEED("送丝速度") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setWireFeedSpeed(ProcessLibRowMapper.nullIfEmptyDouble(cell));
        }
    },
    RETRACT_LENGTH("回抽长度") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setRetractLength(ProcessLibRowMapper.nullIfEmptyDouble(cell));
        }
    },
    RETRACT_SPEED("回抽速度") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setRetractSpeed(ProcessLibRowMapper.nullIfEmptyDouble(cell));
        }
    },
    FILL_LENGTH("补丝长度") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setFillLength(ProcessLibRowMapper.nullIfEmptyDouble(cell));
        }
    },
    PROCESS_TYPE("工艺类型") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            String s = ProcessLibRowMapper.nullIfEmptyString(cell);
            if (s == null) {
                p.setProcessType(null);
            } else {
                p.setProcessType(ProcessDataExcelConvert.convertProcessType(s));
            }
        }
    },
    DATA_TYPE("数据类型") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            String s = ProcessLibRowMapper.nullIfEmptyString(cell);
            if (s == null) {
                p.setDataType(null);
            } else {
                p.setDataType(ProcessDataExcelConvert.convertProcessDataType(s));
            }
        }
    },
    GEAR("档位") {
        @Override
        void apply(ProcessParametersData p, Object cell) {
            p.setGear(ProcessLibRowMapper.nullIfEmptyInteger(cell));
        }
    };

    private final String canonicalHeader;

    ProcessLibColumn(String canonicalHeader) {
        this.canonicalHeader = canonicalHeader;
    }

    String canonicalHeader() {
        return canonicalHeader;
    }

    abstract void apply(ProcessParametersData p, Object cell);
}
