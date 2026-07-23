package com.lasercyber.lws.ui.common.network;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class CameraEth0AddressPlannerTest {

    @Test
    public void pickTabletEth0Address_prefersFirstCandidateWhenNoWlan() {
        assertEquals(
                "192.168.1.234",
                CameraEth0AddressPlanner.pickTabletEth0Address("192.168.1.100", null));
    }

    @Test
    public void pickTabletEth0Address_keepsFirstCandidateWhenWlanDiffers() {
        assertEquals(
                "192.168.1.234",
                CameraEth0AddressPlanner.pickTabletEth0Address("192.168.1.100", "192.168.1.10"));
    }

    @Test
    public void pickTabletEth0Address_avoidsWlanWhenItMatchesFirstCandidate() {
        assertEquals(
                "192.168.1.253",
                CameraEth0AddressPlanner.pickTabletEth0Address("192.168.1.100", "192.168.1.234"));
    }

    @Test
    public void pickTabletEth0Address_ignoresWlanOnDifferentSubnet() {
        assertEquals(
                "192.168.1.234",
                CameraEth0AddressPlanner.pickTabletEth0Address("192.168.1.100", "10.0.0.10"));
    }

    @Test
    public void pickTabletEth0Address_followsCameraSubnet() {
        assertEquals(
                "10.0.0.234",
                CameraEth0AddressPlanner.pickTabletEth0Address("10.0.0.50", null));
    }

    @Test
    public void lanCidr_derivedFromCamera() {
        assertEquals("192.168.1.0/24", CameraEth0AddressPlanner.lanCidr("192.168.1.100"));
    }

    @Test
    public void isUsableHost_rejectsReservedAndConflicts() {
        assertFalse(CameraEth0AddressPlanner.isUsableHost(100, 100, -1));
        assertFalse(CameraEth0AddressPlanner.isUsableHost(10, 100, 10));
        assertTrue(CameraEth0AddressPlanner.isUsableHost(234, 100, 10));
    }
}
