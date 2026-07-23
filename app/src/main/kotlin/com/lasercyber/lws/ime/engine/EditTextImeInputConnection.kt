package com.lasercyber.lws.ime.engine

import android.text.InputType
import android.text.method.PasswordTransformationMethod
import android.text.method.SingleLineTransformationMethod
import android.widget.EditText
import com.lasercyber.lws.ime.ImeAction

class EditTextImeInputConnection(
    private val editText: EditText,
    private val onEditorAction: (ImeAction) -> Boolean = { false },
) : ImeInputConnection {

    private var passwordVisible = false

    override fun commitText(text: CharSequence) {
        val start = editText.selectionStart.coerceAtLeast(0)
        val end = editText.selectionEnd.coerceAtLeast(0)
        editText.text.replace(minOf(start, end), maxOf(start, end), text, 0, text.length)
    }

    override fun clearAll() {
        editText.setText("")
    }

    override fun deleteBackward(codePointCount: Int) {
        val start = editText.selectionStart
        val end = editText.selectionEnd
        if (start != end) {
            editText.text.delete(minOf(start, end), maxOf(start, end))
            return
        }
        if (start > 0) {
            editText.text.delete(start - 1, start)
        }
    }

    override fun performEditorAction(action: ImeAction): Boolean = onEditorAction(action)

    override fun currentText(): String = editText.text?.toString().orEmpty()

    override fun setPasswordVisible(visible: Boolean): Boolean {
        if (!isPasswordField()) {
            passwordVisible = visible
            return visible
        }
        passwordVisible = visible
        editText.transformationMethod = if (visible) {
            SingleLineTransformationMethod.getInstance()
        } else {
            PasswordTransformationMethod.getInstance()
        }
        editText.setSelection(editText.text?.length ?: 0)
        return visible
    }

    override fun isPasswordVisible(): Boolean = passwordVisible

    private fun isPasswordField(): Boolean {
        val variation = editText.inputType and InputType.TYPE_MASK_VARIATION
        return variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
            variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
            variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD
    }
}
