package com.lasercyber.lws.ui.bean.event;

/**
 * Native AI engine state change (EventBus): 0=IDLE, 1=MONITORING, 2=LOCKED.
 */
public class AiEngineStateEvent {
    private final int state;

    public AiEngineStateEvent(int state) {
        this.state = state;
    }

    public int getState() {
        return state;
    }
}
