package com.lasercyber.lws.ui.common.ai.vision;

import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.GsonUtils;
import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;
import com.lasercyber.lws.ui.common.utils.MaterialDisplayNameUtils;
import com.lasercyber.lws.ui.common.utils.convert.EngineerWashConvert;

import java.util.Objects;

/**
 * Resolves Process Type / Material Type display labels for the AI Vision work-information panel.
 */
public final class AiVisionWorkInfoLabels {

  public static final String UNAVAILABLE = "-";

  public static final class Display {
    public final String processType;
    public final String materialType;

    public Display(String processType, String materialType) {
      this.processType = processType;
      this.materialType = materialType;
    }
  }

  @VisibleForTesting
  static final class Resolved {
    @Nullable final Integer processType;
    @Nullable final Integer materialType;
    @Nullable final String materialName;

    Resolved(@Nullable Integer processType, @Nullable Integer materialType, @Nullable String materialName) {
      this.processType = processType;
      this.materialType = materialType;
      this.materialName = materialName;
    }
  }

  private AiVisionWorkInfoLabels() {
  }

  public static Display unavailable() {
    return new Display(UNAVAILABLE, UNAVAILABLE);
  }

  public static Display fromVideo(@Nullable ProcessParamsVideoVo video) {
    return toDisplay(resolveVideo(video));
  }

  public static Display fromSnapshot(@Nullable ProcessParametersData snapshot) {
    if (snapshot == null) {
      return unavailable();
    }
    return toDisplay(new Resolved(
        snapshot.getProcessType(),
        snapshot.getMaterialType(),
        snapshot.getMaterialName()));
  }

  @VisibleForTesting
  @Nullable
  static Resolved resolveVideo(@Nullable ProcessParamsVideoVo video) {
    if (video == null) {
      return null;
    }
    ProcessParametersData parsed = parseProcessParametersJson(video.getProcessParametersJson());
    if (parsed != null) {
      Integer processType = parsed.getProcessType() != null
          ? parsed.getProcessType()
          : video.getProcessType();
      Integer materialType = parsed.getMaterialType() != null
          ? parsed.getMaterialType()
          : video.getMaterialType();
      String materialName = parsed.getMaterialName();
      return new Resolved(processType, materialType, materialName);
    }
    return new Resolved(video.getProcessType(), video.getMaterialType(), null);
  }

  @VisibleForTesting
  static Display toDisplay(@Nullable Resolved resolved) {
    if (resolved == null) {
      return unavailable();
    }
    return new Display(
        formatProcessType(resolved.processType),
        formatMaterialType(resolved.materialType, resolved.materialName));
  }

  @Nullable
  private static ProcessParametersData parseProcessParametersJson(@Nullable String raw) {
    if (StringUtils.isEmpty(raw)) {
      return null;
    }
    try {
      return GsonUtils.fromJson(raw.trim(), ProcessParametersData.class);
    } catch (Exception ignored) {
      return null;
    }
  }

  private static String formatProcessType(@Nullable Integer processType) {
    if (processType == null || !isKnownProcessType(processType)) {
      return UNAVAILABLE;
    }
    return ModelConstant.convertToText(processType);
  }

  private static boolean isKnownProcessType(int processType) {
    return processType >= ModelConstant.CONTINUOUS_WELDING
        && processType <= ModelConstant.CNC_CUT;
  }

  private static String formatMaterialType(@Nullable Integer materialType, @Nullable String materialName) {
    if (materialType == null || !MaterialTypeEnum.isDefinedType(materialType)) {
      return UNAVAILABLE;
    }
    if (Objects.equals(materialType, MaterialTypeEnum.CUSTOMIZE.getType())
        && !StringUtils.isEmpty(materialName)) {
      String localized = MaterialDisplayNameUtils.localizeKnownMaterialName(materialName, materialType);
      return StringUtils.isEmpty(localized) ? materialName : localized;
    }
    String text = EngineerWashConvert.convertCleaningMaterialsText(materialType);
    return StringUtils.isEmpty(text) ? UNAVAILABLE : text;
  }
}
