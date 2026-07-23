package com.lasercyber.lws.ui.bean.entity;

import androidx.annotation.NonNull;
import androidx.room.ColumnInfo;
import androidx.room.Entity;
import androidx.room.PrimaryKey;

import lombok.Data;

/**
 * User-facing general preferences (language, units, sound, boot self-check).
 */
@Data
@Entity(tableName = "t_common_settings")
public class CommonSettings {
    @PrimaryKey(autoGenerate = true)
    private Integer id;
    /** ISO language tag, e.g. {@code zh-CN}, {@code en-US}. */
    private String language;
    /** {@link com.lasercyber.lws.ui.common.enums.UnitSystem} wire value: {@code imperial} or {@code metric}. */
    private String unit;
    /** UI click sound effect index (legacy {@code voiceCheck}). */
    private Integer soundEffect;
    @NonNull
    @ColumnInfo(defaultValue = "1")
    private Boolean showBootSelfCheck = true;
    @NonNull
    @ColumnInfo(defaultValue = "0")
    private Boolean showSafetyGroundLockAlarm = false;
}
