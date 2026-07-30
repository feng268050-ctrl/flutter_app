enum CustomHomeMetric {
  wireConsumption,
  laserOnDuration,
  jobRuntime,
  weldRatio,
  cutRatio,
  cleanRatio,
  weekOverWeekLaser,
  favoriteMaterial,
}

abstract final class CustomHomeLayout {
  static const defaults = <CustomHomeMetric>[
    CustomHomeMetric.wireConsumption,
    CustomHomeMetric.laserOnDuration,
    CustomHomeMetric.jobRuntime,
    CustomHomeMetric.weldRatio,
    CustomHomeMetric.cutRatio,
    CustomHomeMetric.cleanRatio,
    CustomHomeMetric.weekOverWeekLaser,
    CustomHomeMetric.favoriteMaterial,
  ];
}
