package com.lasercyber.lws.ui.common.utils;

import android.os.Handler;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;

import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;

/**
 * 手动进丝/退丝按钮触摸逻辑。
 * <ul>
 *   <li>进丝：短按脉冲；长按送丝，按住约 3 秒进入持续送丝（再点停止）。</li>
 *   <li>退丝：短按脉冲；长按连续退丝，松开立即停止（无持续锁存）。</li>
 * </ul>
 */
public final class ManualWireButtonTouchHelper {

    public static final int PULSE_CLOSE_DELAY_MS = 500;
    private static final int HOLD_FEED_START_MS = 500;
    private static final int CONTINUOUS_FEED_HOLD_MS = 3000;

    public interface Host {
        Handler getHandler();

        boolean isContinuousFeed();

        void setContinuousFeed(boolean continuous);

        void setStartFeedClick(boolean start);

        boolean isContinuousRetract();

        void setContinuousRetract(boolean continuous);

        void setStartRetractClick(boolean start);

        void cancelPulseCloseTask();

        void schedulePulseClose(Runnable closeTask);

        void openFeed(ModbusManagerRtu.WriteCallback callback);

        void closeFeedOrBack(ModbusManagerRtu.WriteCallback callback);

        boolean openBackFeed(ModbusManagerRtu.WriteCallback callback);

        void onContinuousFeedEntered();

        void onContinuousFeedStopped();

        void onContinuousRetractEntered();

        void onContinuousRetractStopped();

        void onFeedPulseSuccess();

        void onFeedPulseFailure();

        void onRetractPulseSuccess();

        void onFeedHoldReleased();

        void onRetractHoldReleased();

        void onRetractPulseFailure();

        void playClickSound();

        void beforeFeedAction();

        void beforeRetractAction();
    }

    private final Host host;
    private final int touchSlop;

    private View feedButton;
    private View retractButton;

    private float feedDownX;
    private float feedDownY;
    private long feedDownTime;
    private boolean feedGestureActive;
    private boolean feedHoldStarted;
    private boolean feedMovedBeyondSlop;
    private boolean feedContinuousEntered;
    /** 本次按下时已是持续送丝，松手用于结束持续送丝（非本次长按 3s 刚进入） */
    private boolean feedTapToStopContinuous;
    private Runnable feedHoldStartRunnable;
    private Runnable feedContinuousRunnable;

    private float retractDownX;
    private float retractDownY;
    private long retractDownTime;
    private boolean retractGestureActive;
    private boolean retractHoldStarted;
    private boolean retractMovedBeyondSlop;
    private Runnable retractHoldStartRunnable;

    public ManualWireButtonTouchHelper(View anyView, Host host) {
        this.host = host;
        this.touchSlop = ViewConfiguration.get(anyView.getContext()).getScaledTouchSlop();
    }

    public void attachFeedButton(View button) {
        feedButton = button;
        button.setOnClickListener(null);
        button.setOnLongClickListener(null);
        button.setOnTouchListener((v, event) -> {
            handleFeedTouch(event);
            return true;
        });
    }

    public void attachRetractButton(View button) {
        retractButton = button;
        button.setOnClickListener(null);
        button.setOnLongClickListener(null);
        button.setOnTouchListener((v, event) -> {
            handleRetractTouch(event);
            return true;
        });
    }

    public void release() {
        clearFeedGesture(false);
        clearRetractGesture();
    }

    private void handleFeedTouch(MotionEvent event) {
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                if (host.isContinuousFeed()) {
                    feedGestureActive = true;
                    feedTapToStopContinuous = true;
                    setFeedPressed(true);
                    return;
                }
                feedTapToStopContinuous = false;
                beginFeedGesture(event);
                break;
            case MotionEvent.ACTION_MOVE:
                if (!feedGestureActive || host.isContinuousFeed()) {
                    return;
                }
                if (movedBeyondSlop(event.getX(), event.getY(), feedDownX, feedDownY)) {
                    feedMovedBeyondSlop = true;
                    cancelFeedContinuousTimer();
                    if (feedHoldStarted) {
                        endHoldFeed(false);
                    }
                }
                break;
            case MotionEvent.ACTION_UP:
                if (feedTapToStopContinuous && host.isContinuousFeed()) {
                    feedGestureActive = false;
                    feedTapToStopContinuous = false;
                    setFeedPressed(false);
                    host.playClickSound();
                    stopContinuousFeed();
                    return;
                }
                if (!feedGestureActive) {
                    return;
                }
                finishFeedGesture(false);
                break;
            case MotionEvent.ACTION_CANCEL:
                if (feedTapToStopContinuous) {
                    feedGestureActive = false;
                    feedTapToStopContinuous = false;
                    setFeedPressed(false);
                    return;
                }
                if (!feedGestureActive) {
                    return;
                }
                finishFeedGesture(true);
                break;
            default:
                break;
        }
    }

    private void beginFeedGesture(MotionEvent event) {
        clearFeedGesture(false);
        feedGestureActive = true;
        setFeedPressed(true);
        feedDownX = event.getX();
        feedDownY = event.getY();
        feedDownTime = System.currentTimeMillis();
        feedHoldStartRunnable = () -> {
            if (!feedGestureActive || feedMovedBeyondSlop || host.isContinuousFeed()) {
                return;
            }
            feedHoldStarted = true;
            host.beforeFeedAction();
            host.playClickSound();
            host.setStartFeedClick(true);
            host.openFeed(null);
        };
        feedContinuousRunnable = () -> {
            if (!feedGestureActive || feedMovedBeyondSlop || host.isContinuousFeed()) {
                return;
            }
            feedContinuousEntered = true;
            feedHoldStarted = true;
            host.setStartFeedClick(false);
            host.setContinuousFeed(true);
            host.onContinuousFeedEntered();
        };
        host.getHandler().postDelayed(feedHoldStartRunnable, HOLD_FEED_START_MS);
        host.getHandler().postDelayed(feedContinuousRunnable, CONTINUOUS_FEED_HOLD_MS);
    }

    private void finishFeedGesture(boolean canceled) {
        long holdDuration = System.currentTimeMillis() - feedDownTime;
        boolean treatAsCancel = canceled || feedMovedBeyondSlop;

        if (feedContinuousEntered) {
            clearFeedGesture(true);
            return;
        }

        if (feedHoldStarted) {
            host.beforeFeedAction();
            host.closeFeedOrBack(null);
            host.onFeedHoldReleased();
            clearFeedGesture(false);
            return;
        }

        cancelFeedHoldTimer();
        cancelFeedContinuousTimer();

        if (treatAsCancel) {
            clearFeedGesture(false);
            return;
        }

        if (holdDuration < HOLD_FEED_START_MS) {
            performFeedPulse();
        }
        clearFeedGesture(false);
    }

    private void performFeedPulse() {
        host.cancelPulseCloseTask();
        host.beforeFeedAction();
        host.playClickSound();
        host.openFeed(new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                host.onFeedPulseSuccess();
                Runnable closeTask = () -> host.closeFeedOrBack(null);
                host.schedulePulseClose(closeTask);
            }

            @Override
            public void onFailure() {
                host.onFeedPulseFailure();
            }
        });
    }

    private void endHoldFeed(boolean enteringContinuous) {
        if (!feedHoldStarted) {
            return;
        }
        feedHoldStarted = false;
        host.setStartFeedClick(false);
        if (!enteringContinuous && !feedContinuousEntered) {
            host.closeFeedOrBack(null);
        }
    }

    private void stopContinuousFeed() {
        host.setContinuousFeed(false);
        host.setStartFeedClick(false);
        host.closeFeedOrBack(null);
        host.onContinuousFeedStopped();
    }

    private void clearFeedGesture(boolean keepContinuous) {
        feedGestureActive = false;
        feedTapToStopContinuous = false;
        cancelFeedHoldTimer();
        cancelFeedContinuousTimer();
        if (feedHoldStarted && !feedContinuousEntered && !keepContinuous) {
            host.closeFeedOrBack(null);
        }
        feedHoldStarted = false;
        feedMovedBeyondSlop = false;
        if (!keepContinuous) {
            feedContinuousEntered = false;
            host.setStartFeedClick(false);
        }
        setFeedPressed(false);
    }

    private void cancelFeedHoldTimer() {
        if (feedHoldStartRunnable != null) {
            host.getHandler().removeCallbacks(feedHoldStartRunnable);
            feedHoldStartRunnable = null;
        }
    }

    private void cancelFeedContinuousTimer() {
        if (feedContinuousRunnable != null) {
            host.getHandler().removeCallbacks(feedContinuousRunnable);
            feedContinuousRunnable = null;
        }
    }

    private void handleRetractTouch(MotionEvent event) {
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                beginRetractGesture(event);
                break;
            case MotionEvent.ACTION_MOVE:
                if (!retractGestureActive) {
                    return;
                }
                if (movedBeyondSlop(event.getX(), event.getY(), retractDownX, retractDownY)) {
                    retractMovedBeyondSlop = true;
                    if (retractHoldStarted) {
                        endHoldRetract();
                    }
                }
                break;
            case MotionEvent.ACTION_UP:
                if (!retractGestureActive) {
                    return;
                }
                finishRetractGesture(false);
                break;
            case MotionEvent.ACTION_CANCEL:
                if (!retractGestureActive) {
                    return;
                }
                finishRetractGesture(true);
                break;
            default:
                break;
        }
    }

    private void beginRetractGesture(MotionEvent event) {
        clearRetractGesture();
        host.cancelPulseCloseTask();
        // Ensure any leftover latched retract state from older builds is cleared.
        if (host.isContinuousRetract()) {
            host.setContinuousRetract(false);
            host.onContinuousRetractStopped();
        }
        retractGestureActive = true;
        setRetractPressed(true);
        retractDownX = event.getX();
        retractDownY = event.getY();
        retractDownTime = System.currentTimeMillis();
        retractHoldStartRunnable = () -> {
            if (!retractGestureActive || retractMovedBeyondSlop) {
                return;
            }
            retractHoldStarted = true;
            host.beforeRetractAction();
            host.playClickSound();
            host.setStartRetractClick(true);
            host.openBackFeed(null);
        };
        host.getHandler().postDelayed(retractHoldStartRunnable, HOLD_FEED_START_MS);
    }

    private void finishRetractGesture(boolean canceled) {
        long holdDuration = System.currentTimeMillis() - retractDownTime;
        boolean treatAsCancel = canceled || retractMovedBeyondSlop;

        if (retractHoldStarted) {
            host.closeFeedOrBack(null);
            host.onRetractHoldReleased();
            clearRetractGesture();
            return;
        }

        cancelRetractHoldTimer();

        if (!treatAsCancel && holdDuration < HOLD_FEED_START_MS) {
            performRetractPulse();
        }
        clearRetractGesture();
    }

    private void performRetractPulse() {
        host.cancelPulseCloseTask();
        host.beforeRetractAction();
        host.playClickSound();
        if (!host.openBackFeed(new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                host.onRetractPulseSuccess();
                host.schedulePulseClose(() -> host.closeFeedOrBack(null));
            }

            @Override
            public void onFailure() {
                host.onRetractPulseFailure();
            }
        })) {
            return;
        }
    }

    private void endHoldRetract() {
        if (!retractHoldStarted) {
            return;
        }
        retractHoldStarted = false;
        host.setStartRetractClick(false);
        host.closeFeedOrBack(null);
    }

    private void clearRetractGesture() {
        retractGestureActive = false;
        cancelRetractHoldTimer();
        if (retractHoldStarted) {
            host.closeFeedOrBack(null);
        }
        retractHoldStarted = false;
        retractMovedBeyondSlop = false;
        host.setStartRetractClick(false);
        setRetractPressed(false);
    }

    private void setFeedPressed(boolean pressed) {
        if (feedButton != null) {
            feedButton.setPressed(pressed);
        }
    }

    private void setRetractPressed(boolean pressed) {
        if (retractButton != null) {
            retractButton.setPressed(pressed);
        }
    }

    private void cancelRetractHoldTimer() {
        if (retractHoldStartRunnable != null) {
            host.getHandler().removeCallbacks(retractHoldStartRunnable);
            retractHoldStartRunnable = null;
        }
    }

    private boolean movedBeyondSlop(float x, float y, float downX, float downY) {
        return Math.abs(x - downX) > touchSlop || Math.abs(y - downY) > touchSlop;
    }
}
