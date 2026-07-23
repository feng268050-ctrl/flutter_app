package com.lasercyber.lws.ui.common.utils;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class ShellCmdUtilTest {

    @Test
    public void parsePingReachableOutput_acceptsCleanSingleReply() {
        String output = "PING 192.168.1.100 (192.168.1.100) 56(84) bytes of data.\n"
                + "64 bytes from 192.168.1.100: icmp_seq=1 ttl=64 time=0.5 ms\n"
                + "\n"
                + "--- 192.168.1.100 ping statistics ---\n"
                + "1 packets transmitted, 1 received, 0% packet loss, time 0ms\n";
        assertTrue(ShellCmdUtil.parsePingReachableOutput(output));
    }

    @Test
    public void parsePingReachableOutput_rejectsUnreachable() {
        String output = "From 10.0.2.2: icmp_seq=1 Destination Net Unreachable\n"
                + "\n"
                + "--- 192.168.0.237 ping statistics ---\n"
                + "1 packets transmitted, 0 received, 100% packet loss, time 0ms\n";
        assertFalse(ShellCmdUtil.parsePingReachableOutput(output));
    }

    @Test
    public void parsePingReachableOutput_rejectsPacketLossAndErrors() {
        String output = "64 bytes from 192.168.0.237: icmp_seq=0 ttl=255 time=1 ms\n"
                + "wrong data byte #16 should be 0x10 but was 0xc0\n"
                + "\n"
                + "--- 192.168.0.237 ping statistics ---\n"
                + "4 packets transmitted, 1 received, +2 duplicates, +1 errors, 75% packet loss, time 3033ms\n";
        assertFalse(ShellCmdUtil.parsePingReachableOutput(output));
    }
}
