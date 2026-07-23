package com.lasercyber.lws.ui.component.popup;

import lombok.Data;
import lombok.experimental.Accessors;

/** Item model for {@link FrostPopupMenu}. */
@Data
@Accessors(chain = true)
public class PopupMenuItem {
    private int iconRes;
    private CharSequence label;
    private boolean selected;
    private Object tag;
}
