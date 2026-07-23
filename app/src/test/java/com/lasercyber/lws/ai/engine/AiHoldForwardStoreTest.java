package com.lasercyber.lws.ai.engine;
import com.lasercyber.lws.ai.engine.AiHoldForwardStore;

import org.junit.Assert;
import org.junit.Test;

public class AiHoldForwardStoreTest {

    @Test
    public void holdsLastValueUntilUpdated() {
        AiHoldForwardStore<String> store = new AiHoldForwardStore<>();
        Assert.assertNull(store.get());
        store.set("a");
        Assert.assertEquals("a", store.get());
        store.set("b");
        Assert.assertEquals("b", store.get());
    }
}

