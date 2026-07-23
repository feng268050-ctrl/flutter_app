package com.lasercyber.lws.ui.common.state;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotSame;
import static org.junit.Assert.assertNull;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;

import org.junit.After;
import org.junit.Test;

public class ProcessParametersSnapshotStoreTest {

    @After
    public void resetStore() {
        ProcessParametersSnapshotStore.update(null);
    }

    @Test
    public void consecutive_updates_keep_latest_values() {
        ProcessParametersData first = new ProcessParametersData();
        first.setLaserPower(10);
        first.setProcessType(1);
        ProcessParametersSnapshotStore.update(first);

        ProcessParametersData second = new ProcessParametersData();
        second.setLaserPower(99);
        second.setProcessType(1);
        ProcessParametersSnapshotStore.update(second);

        ProcessParametersData snap = ProcessParametersSnapshotStore.getSnapshot();
        assertEquals(Integer.valueOf(99), snap.getLaserPower());
    }

    @Test
    public void get_snapshot_returns_clone_mutating_read_does_not_affect_store() {
        ProcessParametersData data = new ProcessParametersData();
        data.setLaserPower(55);
        ProcessParametersSnapshotStore.update(data);

        ProcessParametersData a = ProcessParametersSnapshotStore.getSnapshot();
        ProcessParametersData b = ProcessParametersSnapshotStore.getSnapshot();
        assertNotSame(a, b);
        a.setLaserPower(1);
        ProcessParametersData again = ProcessParametersSnapshotStore.getSnapshot();
        assertEquals(Integer.valueOf(55), again.getLaserPower());
    }

    @Test
    public void update_null_clears_snapshot() {
        ProcessParametersData data = new ProcessParametersData();
        data.setLaserPower(1);
        ProcessParametersSnapshotStore.update(data);
        ProcessParametersSnapshotStore.update(null);
        assertNull(ProcessParametersSnapshotStore.getSnapshot());
    }
}
