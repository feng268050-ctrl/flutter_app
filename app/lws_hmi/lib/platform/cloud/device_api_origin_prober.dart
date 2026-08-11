import 'package:cyber_hal/network/cloud_origin.dart';

export 'package:cyber_hal/network/cloud_origin.dart'
    show CloudApiOriginProber, CloudHttpProbe;

/// Compatibility alias for existing HMI call sites.
typedef DeviceApiOriginProber = CloudApiOriginProber;
