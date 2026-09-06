import QtQuick

/*! The one way a group of things is titled: small, spaced, quiet. */
Text {
    color: Theme.textMuted
    font.family: Theme.sansFamily
    font.pixelSize: Theme.micro
    font.weight: Font.Medium
    font.letterSpacing: 0.9
    font.capitalization: Font.AllUppercase
    elide: Text.ElideRight
}
