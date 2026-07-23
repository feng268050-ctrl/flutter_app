package com.lasercyber.lws.ui.component.adapter;

import com.lasercyber.lws.frostui.control.FrostStatusState;
import com.lasercyber.lws.ui.activitys.device.monitor.CommStatusDisplay;

import org.junit.Assert;
import org.junit.Test;

public class CommStatusBindingAdapterTest {

    @Test
    public void commStatusDisplayMapsToIndicatorState() {
        Assert.assertEquals(FrostStatusState.Idle,
                CommStatusBindingAdapter.toStatusState(CommStatusDisplay.NEUTRAL));
        Assert.assertEquals(FrostStatusState.Success,
                CommStatusBindingAdapter.toStatusState(CommStatusDisplay.HEALTHY));
        Assert.assertEquals(FrostStatusState.Failure,
                CommStatusBindingAdapter.toStatusState(CommStatusDisplay.FAULT));
    }

    @Test
    public void resolveCommMapsToExpectedDisplayStates() {
        Assert.assertEquals(FrostStatusState.Idle,
                CommStatusBindingAdapter.toStatusState(
                        CommStatusDisplay.resolve(true, false, false)));
        Assert.assertEquals(FrostStatusState.Success,
                CommStatusBindingAdapter.toStatusState(
                        CommStatusDisplay.resolve(false, true, false)));
        Assert.assertEquals(FrostStatusState.Failure,
                CommStatusBindingAdapter.toStatusState(
                        CommStatusDisplay.resolve(false, true, true)));
    }

    @Test
    public void resolveCameraCommMapsToExpectedDisplayStates() {
        Assert.assertEquals(FrostStatusState.Idle,
                CommStatusBindingAdapter.toStatusState(
                        CommStatusDisplay.resolveCameraComm(true, true, true, false)));
        Assert.assertEquals(FrostStatusState.Success,
                CommStatusBindingAdapter.toStatusState(
                        CommStatusDisplay.resolveCameraComm(true, true, false, true)));
        Assert.assertEquals(FrostStatusState.Failure,
                CommStatusBindingAdapter.toStatusState(
                        CommStatusDisplay.resolveCameraComm(true, true, true, true)));
    }

    @Test
    public void resolveMetricMapsToExpectedDisplayStates() {
        Assert.assertEquals(FrostStatusState.Idle,
                CommStatusBindingAdapter.toStatusState(
                        CommStatusDisplay.resolveMetric(false, true, false)));
        Assert.assertEquals(FrostStatusState.Idle,
                CommStatusBindingAdapter.toStatusState(
                        CommStatusDisplay.resolveMetric(true, false, true)));
        Assert.assertEquals(FrostStatusState.Success,
                CommStatusBindingAdapter.toStatusState(
                        CommStatusDisplay.resolveMetric(true, true, false)));
        Assert.assertEquals(FrostStatusState.Failure,
                CommStatusBindingAdapter.toStatusState(
                        CommStatusDisplay.resolveMetric(true, true, true)));
    }
}
