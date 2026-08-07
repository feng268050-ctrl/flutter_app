import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/region_settings_policy.dart';

void main() {
  test('first apply migrates Asia/Shanghai and China NTP to US defaults', () {
    final plan = RegionSettingsPolicy.planClockApply(
      previousCountry: null,
      nextCountry: 'US',
      currentTimezone: 'Asia/Shanghai',
      autoTimezone: false,
      currentNtp: 'cn.pool.ntp.org',
    );
    expect(plan.applyTimezone, isTrue);
    expect(plan.timezone, 'America/New_York');
    expect(plan.applyNtp, isTrue);
    expect(plan.ntpServerId, 'pool.ntp.org');
    expect(plan.ntpServerId, isNot('cn.pool.ntp.org'));
  });

  test('US to DE updates linked timezone and NTP', () {
    final plan = RegionSettingsPolicy.planClockApply(
      previousCountry: 'US',
      nextCountry: 'DE',
      currentTimezone: 'America/New_York',
      autoTimezone: false,
      currentNtp: 'pool.ntp.org',
    );
    expect(plan.applyTimezone, isTrue);
    expect(plan.timezone, 'Europe/Berlin');
    expect(plan.applyNtp, isTrue);
    expect(plan.ntpServerId, 'pool.ntp.org');
  });

  test('custom timezone is preserved', () {
    final plan = RegionSettingsPolicy.planClockApply(
      previousCountry: 'US',
      nextCountry: 'DE',
      currentTimezone: 'America/Los_Angeles',
      autoTimezone: false,
      currentNtp: 'time.cloudflare.com',
    );
    expect(plan.applyTimezone, isFalse);
    expect(plan.applyNtp, isFalse);
  });

  test('auto_timezone skips timezone overwrite', () {
    final plan = RegionSettingsPolicy.planClockApply(
      previousCountry: 'US',
      nextCountry: 'DE',
      currentTimezone: 'America/New_York',
      autoTimezone: true,
      currentNtp: 'pool.ntp.org',
    );
    expect(plan.applyTimezone, isFalse);
    expect(plan.applyNtp, isTrue);
  });
}
