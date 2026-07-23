package com.lasercyber.lws.ime.engine

import com.lasercyber.lws.ime.ImeAction

interface ImeInputConnection {
    fun commitText(text: CharSequence)
    fun deleteBackward(codePointCount: Int = 1)
    fun clearAll()
    fun performEditorAction(action: ImeAction): Boolean
    fun currentText(): String = ""
    fun setPasswordVisible(visible: Boolean): Boolean = visible
    fun isPasswordVisible(): Boolean = false
}
