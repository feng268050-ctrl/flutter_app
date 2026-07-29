/// App environment tier for Worker API candidate selection (lws-ui parity).
enum CloudEnvironmentTier {
  /// Local / debug Worker candidates.
  dev,

  /// Test Worker (`api-test…`).
  test,

  /// Production Worker (`api-prod…`).
  prod,
}

extension CloudEnvironmentTierCodec on CloudEnvironmentTier {
  String get wireName => name;

  static CloudEnvironmentTier parse(String? raw, {CloudEnvironmentTier fallback = CloudEnvironmentTier.test}) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'dev':
      case 'debug':
        return CloudEnvironmentTier.dev;
      case 'prod':
      case 'production':
        return CloudEnvironmentTier.prod;
      case 'test':
        return CloudEnvironmentTier.test;
      default:
        return fallback;
    }
  }
}
