package com.lasercyber.lws.ime.keyboard.layout

import com.lasercyber.lws.ime.field.ImeBottomRowProfile
import com.lasercyber.lws.ime.keyboard.KeyDef
import com.lasercyber.lws.ime.keyboard.KeyId
import com.lasercyber.lws.ime.keyboard.KeyboardKind
import com.lasercyber.lws.ime.keyboard.KeyboardLayout
import com.lasercyber.lws.ime.keyboard.KeyboardRow

object GlobalQwertyLayout {
    private val row1Secondaries = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "0")
    private val row2Secondaries = listOf("~", "!", "@", "#", "%", "\"", "'", "*", "?")
    private val row3Secondaries = listOf("(", ")", "-", "_", ":", ";", "/")

    fun layout(
        kind: KeyboardKind,
        bottomRowProfile: ImeBottomRowProfile = ImeBottomRowProfile.Default,
        numericModeLabel: Boolean = false,
    ): KeyboardLayout {
        val letters1 = listOf("Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P")
        val letters2 = listOf("A", "S", "D", "F", "G", "H", "J", "K", "L")
        val letters3 = listOf("Z", "X", "C", "V", "B", "N", "M")

        val row1 = KeyboardRow(
            letters1.mapIndexed { index, letter ->
                KeyDef(
                    id = KeyId.Letter,
                    primary = letter,
                    secondary = row1Secondaries[index],
                    isLetter = true,
                )
            },
        )
        val row2 = KeyboardRow(
            keys = letters2.mapIndexed { index, letter ->
                KeyDef(
                    id = KeyId.Letter,
                    primary = letter,
                    secondary = row2Secondaries[index],
                    isLetter = true,
                )
            },
            leadingInsetWeight = 0.5f,
            trailingInsetWeight = 0.5f,
        )
        val row3 = KeyboardRow(
            buildList {
                add(KeyDef(id = KeyId.Shift, primary = "⇧", widthWeight = 1.4f))
                addAll(
                    letters3.mapIndexed { index, letter ->
                        KeyDef(
                            id = KeyId.Letter,
                            primary = letter,
                            secondary = row3Secondaries[index],
                            isLetter = true,
                        )
                    },
                )
                add(KeyDef(id = KeyId.Backspace, primary = "⌫", widthWeight = 1.4f))
            },
        )
        val row4 = KeyboardRow(bottomRowProfile.fourthRowKeys(numericModeLabel))
        return KeyboardLayout(kind = kind, rows = listOf(row1, row2, row3, row4))
    }
}

/**
 * Keyboard A — primary symbol layer (123 toggle), rows 1–3 match iOS figure 2:
 * ```
 * 1  2  3  4  5  6  7  8  9  0
 * -  /  :  ;  (  )  $  &  @  "
 * #+=  ,  .  ?  !  '  ⌫
 * ABC  [space]  ⏎
 * ```
 */
object GlobalSymbolsPrimaryLayout {
    fun layout(): KeyboardLayout = KeyboardLayout(
        kind = KeyboardKind.NumericGlobal,
        rows = listOf(
            KeyboardRow(
                listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "0").map { digit(it) },
            ),
            KeyboardRow(
                listOf(
                    symbol("-"),
                    symbol("/"),
                    symbol(":"),
                    symbol(";"),
                    symbol("("),
                    symbol(")"),
                    symbol("$"),
                    symbol("&"),
                    KeyDef(id = KeyId.At, primary = "@"),
                    symbol("\""),
                ),
            ),
            KeyboardRow(
                listOf(
                    KeyDef(id = KeyId.SymbolsMore, primary = "#+=", widthWeight = 1.4f),
                    symbol(","),
                    symbol("."),
                    symbol("?"),
                    symbol("!"),
                    quoteKey(),
                    KeyDef(id = KeyId.Backspace, primary = "⌫", widthWeight = 1.2f),
                ),
            ),
            symbolBottomRow(),
        ),
    )

    internal fun symbolBottomRow(): KeyboardRow = KeyboardRow(
        listOf(
            KeyDef(id = KeyId.ModeSwitch, primary = "ABC", widthWeight = 1.4f),
            KeyDef(id = KeyId.Space, primary = " ", widthWeight = 4f),
            KeyDef(id = KeyId.Enter, primary = "⏎", widthWeight = 1.4f),
        ),
    )

    private fun digit(value: String) = KeyDef(id = KeyId.Digit, primary = value)

    private fun symbol(value: String) = KeyDef(id = KeyId.Custom, primary = value)
}

private fun quoteKey() = KeyDef(id = KeyId.Custom, primary = "'", secondary = "`")

/**
 * Keyboard A — extended symbol layer (#+=), rows 1–3 match iOS figure 3:
 * ```
 * [  ]  {  }  #  %  ^  *  +  =
 * _  \  |  ~  <  >  €  £  ¥  •
 * 123  ,  .  ?  !  '  ⌫
 * ABC  [space]  ⏎
 * ```
 */
object GlobalSymbolsExtendedLayout {
    fun layout(): KeyboardLayout = KeyboardLayout(
        kind = KeyboardKind.SymbolsExtendedGlobal,
        rows = listOf(
            KeyboardRow(
                listOf(
                    symbol("["),
                    symbol("]"),
                    symbol("{"),
                    symbol("}"),
                    symbol("#"),
                    symbol("%"),
                    symbol("^"),
                    symbol("*"),
                    symbol("+"),
                    symbol("="),
                ),
            ),
            KeyboardRow(
                listOf(
                    symbol("_"),
                    symbol("\\"),
                    symbol("|"),
                    symbol("~"),
                    symbol("<"),
                    symbol(">"),
                    symbol("€"),
                    symbol("£"),
                    symbol("¥"),
                    symbol("•"),
                ),
            ),
            KeyboardRow(
                listOf(
                    KeyDef(id = KeyId.ModeSwitch, primary = "123", widthWeight = 1.4f),
                    symbol(","),
                    symbol("."),
                    symbol("?"),
                    symbol("!"),
                    quoteKey(),
                    KeyDef(id = KeyId.Backspace, primary = "⌫", widthWeight = 1.2f),
                ),
            ),
            GlobalSymbolsPrimaryLayout.symbolBottomRow(),
        ),
    )

    private fun symbol(value: String) = KeyDef(id = KeyId.Custom, primary = value)
}

/** @deprecated Use [GlobalSymbolsPrimaryLayout]; kept for test migration reference. */
@Deprecated("Renamed to GlobalSymbolsPrimaryLayout", ReplaceWith("GlobalSymbolsPrimaryLayout"))
object GlobalNumericLayout {
    fun layout(): KeyboardLayout = GlobalSymbolsPrimaryLayout.layout()
}

/**
 * Keyboard B — dedicated numeric pad:
 * ```
 * 1  2  3  ⌫
 * 4  5  6  C
 * 7  8  9  -
 * .  0  00  ⏎
 * ```
 */
object DedicatedNumericLayout {
    fun layout(): KeyboardLayout = KeyboardLayout(
        kind = KeyboardKind.NumericDedicated,
        rows = listOf(
            KeyboardRow(
                listOf(
                    digit("1"),
                    digit("2"),
                    digit("3"),
                    KeyDef(id = KeyId.Backspace, primary = "⌫"),
                ),
            ),
            KeyboardRow(
                listOf(
                    digit("4"),
                    digit("5"),
                    digit("6"),
                    KeyDef(id = KeyId.Clear, primary = "C"),
                ),
            ),
            KeyboardRow(
                listOf(
                    digit("7"),
                    digit("8"),
                    digit("9"),
                    KeyDef(id = KeyId.Minus, primary = "-"),
                ),
            ),
            KeyboardRow(
                listOf(
                    KeyDef(id = KeyId.DecimalPeriod, primary = "."),
                    digit("0"),
                    KeyDef(id = KeyId.Custom, primary = "00"),
                    KeyDef(id = KeyId.Enter, primary = "⏎"),
                ),
            ),
        ),
    )

    private fun digit(value: String) = KeyDef(id = KeyId.Digit, primary = value)
}
