package com.lasercyber.lws.ui.common.upgrade;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import android.content.SharedPreferences;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;

public class AutoCheckOtaUpdateSettingsTest {

    private MapSharedPreferences prefs;

    @Before
    public void setUp() {
        prefs = new MapSharedPreferences();
        AutoCheckOtaUpdateSettings.resetForTest();
        AutoCheckOtaUpdateSettings.testPrefsOverride = prefs;
    }

    @After
    public void tearDown() {
        AutoCheckOtaUpdateSettings.resetForTest();
    }

    @Test
    public void defaultsDisabled() {
        assertFalse(AutoCheckOtaUpdateSettings.isEnabled(null));
    }

    @Test
    public void persistsEnabledFlag() {
        AutoCheckOtaUpdateSettings.setEnabled(null, true);
        assertTrue(AutoCheckOtaUpdateSettings.isEnabled(null));
        assertTrue(Boolean.TRUE.equals(prefs.map.get("enabled")));
    }

    @Test
    public void testOverrideTakesPrecedence() {
        AutoCheckOtaUpdateSettings.setEnabledOverrideForTest(false);
        AutoCheckOtaUpdateSettings.setEnabled(null, true);
        assertFalse(AutoCheckOtaUpdateSettings.isEnabled(null));
    }

    private static final class MapSharedPreferences implements SharedPreferences {
        final Map<String, Object> map = new HashMap<>();

        @Override
        public Map<String, ?> getAll() {
            return map;
        }

        @Override
        public String getString(String key, String defValue) {
            return defValue;
        }

        @Override
        public Set<String> getStringSet(String key, Set<String> defValues) {
            return defValues;
        }

        @Override
        public int getInt(String key, int defValue) {
            return defValue;
        }

        @Override
        public long getLong(String key, long defValue) {
            return defValue;
        }

        @Override
        public float getFloat(String key, float defValue) {
            return defValue;
        }

        @Override
        public boolean getBoolean(String key, boolean defValue) {
            Object value = map.get(key);
            return value instanceof Boolean ? (Boolean) value : defValue;
        }

        @Override
        public boolean contains(String key) {
            return map.containsKey(key);
        }

        @Override
        public Editor edit() {
            return new Editor() {
                @Override
                public Editor putBoolean(String key, boolean value) {
                    map.put(key, value);
                    return this;
                }

                @Override
                public Editor putString(String key, String value) {
                    return this;
                }

                @Override
                public Editor putStringSet(String key, Set<String> values) {
                    return this;
                }

                @Override
                public Editor putInt(String key, int value) {
                    return this;
                }

                @Override
                public Editor putLong(String key, long value) {
                    return this;
                }

                @Override
                public Editor putFloat(String key, float value) {
                    return this;
                }

                @Override
                public Editor remove(String key) {
                    map.remove(key);
                    return this;
                }

                @Override
                public Editor clear() {
                    map.clear();
                    return this;
                }

                @Override
                public boolean commit() {
                    return true;
                }

                @Override
                public void apply() {
                }
            };
        }

        @Override
        public void registerOnSharedPreferenceChangeListener(OnSharedPreferenceChangeListener listener) {
        }

        @Override
        public void unregisterOnSharedPreferenceChangeListener(OnSharedPreferenceChangeListener listener) {
        }
    }
}
