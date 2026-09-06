import QtQuick

/*! The one way a group of things is titled: small, spaced, quiet. */
Text {
    color: Theme.textMuted
    font.family: Theme.sansFamily
    font.pixelSize: Theme.caption
    font.weight: Font.Medium
    font.letterSpacing: 0
    font.capitalization: Font.MixedCase
    elide: Text.ElideRight
}
