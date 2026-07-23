package com.lasercyber.lws.ui.common.device;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import android.content.SharedPreferences;

import com.lasercyber.lws.ui.network.ws.DeviceWebSocketEnvelope;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

public class DeviceRemoteLockStoreTest {

    private MapSharedPreferences prefs;

    @Before
    public void setUp() {
        prefs = new MapSharedPreferences();
        DeviceRemoteLockStore.testPrefsOverride = prefs;
    }

    @After
    public void tearDown() {
        DeviceRemoteLockStore.testPrefsOverride = null;
    }

    @Test
    public void defaults_unlocked() {
        assertFalse(DeviceRemoteLockStore.isLocked());
    }

    @Test
    public void lock_persists_in_preferences() {
        DeviceRemoteLockStore.setLocked(true);
        assertTrue(DeviceRemoteLockStore.isLocked());
        assertTrue(Boolean.TRUE.equals(prefs.map.get("remote_locked")));
    }

    @Test
    public void unlock_clears_flag() {
        DeviceRemoteLockStore.setLocked(true);
        DeviceRemoteLockStore.setLocked(false);
        assertFalse(DeviceRemoteLockStore.isLocked());
    }

    @Test
    public void lock_and_unlock_envelopes_parse() {
        Map<String, Object> emptyPayload = Collections.emptyMap();
        String lockJson = DeviceWebSocketEnvelope.toJson("command.lock", emptyPayload, "lock-1", 1L);
        assertEquals("command.lock", DeviceWebSocketEnvelope.parse(lockJson).type);
        String unlockJson = DeviceWebSocketEnvelope.toJson("command.unlock", emptyPayload, "unlock-1", 2L);
        assertEquals("command.unlock", DeviceWebSocketEnvelope.parse(unlockJson).type);
    }

    @Test
    public void listener_notified_on_change() throws InterruptedException {
        AtomicBoolean value = new AtomicBoolean();
        DeviceRemoteLockStore.Listener listener = value::set;
        DeviceRemoteLockStore.addListener(listener);
        DeviceRemoteLockStore.setLocked(true);
        Thread.sleep(50);
        assertTrue(value.get());
        DeviceRemoteLockStore.removeListener(listener);
    }

    /** Minimal in-memory {@link SharedPreferences} for unit tests. */
    static final class MapSharedPreferences implements SharedPreferences {
        final Map<String, Object> map = new HashMap<>();

        @Override
        public Map<String, ?> getAll() {
            return map;
        }

        @Override
        public String getString(String key, String defValue) {
            Object v = map.get(key);
            return v instanceof String ? (String) v : defValue;
        }

        @Override
        public Set<String> getStringSet(String key, Set<String> defValues) {
            Object v = map.get(key);
            if (v instanceof Set) {
                @SuppressWarnings("unchecked")
                Set<String> set = (Set<String>) v;
                return set;
            }
            return defValues;
        }

        @Override
        public void registerOnSharedPreferenceChangeListener(OnSharedPreferenceChangeListener listener) {
        }

        @Override
        public void unregisterOnSharedPreferenceChangeListener(OnSharedPreferenceChangeListener listener) {
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
            Object v = map.get(key);
            return v instanceof Boolean ? (Boolean) v : defValue;
        }

        @Override
        public boolean contains(String key) {
            return map.containsKey(key);
        }

        @Override
        public Editor edit() {
            return new Editor() {
                private final Map<String, Object> pending = new HashMap<>();

                @Override
                public Editor putBoolean(String key, boolean value) {
                    pending.put(key, value);
                    return this;
                }

                @Override
                public Editor putString(String key, String value) {
                    pending.put(key, value);
                    return this;
                }

                @Override
                public Editor putStringSet(String key, Set<String> values) {
                    pending.put(key, values != null ? new HashSet<>(values) : null);
                    return this;
                }

                @Override
                public Editor putInt(String key, int value) {
                    pending.put(key, value);
                    return this;
                }

                @Override
                public Editor putLong(String key, long value) {
                    pending.put(key, value);
                    return this;
                }

                @Override
                public Editor putFloat(String key, float value) {
                    pending.put(key, value);
                    return this;
                }

                @Override
                public Editor remove(String key) {
                    pending.put(key, null);
                    return this;
                }

                @Override
                public Editor clear() {
                    pending.clear();
                    map.clear();
                    return this;
                }

                @Override
                public boolean commit() {
                    apply();
                    return true;
                }

                @Override
                public void apply() {
                    for (Map.Entry<String, Object> e : pending.entrySet()) {
                        if (e.getValue() == null) {
                            map.remove(e.getKey());
                        } else {
                            map.put(e.getKey(), e.getValue());
                        }
                    }
                    pending.clear();
                }
            };
        }
    }
}
