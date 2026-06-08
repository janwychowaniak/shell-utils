# shellcheck shell=bash
# [https://www.shellhacks.com/bash-colors/]


# ==========================================================================
_jwStyleParamNormal_="0"

__jwStyleGetMarker__() {
    printf '\e[%sm' "$1"
}

__jwStylePaintGeneric__() {
    local styleParam=$1
    local content=$2
    printf '%s' "$(__jwStyleGetMarker__ "$styleParam")$content$(__jwStyleGetMarker__ "$_jwStyleParamNormal_")"
}
# ==========================================================================


# styles -------------------------------------------------------------------
_jwStyleParamBold_="1"
_jwStyleParamUnderl_="4"
_jwStyleParamBlink_="5"

jwpaintfgBold() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamBold_" "$1")"
}

jwpaintfgUnderl() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamUnderl_" "$1")"
}

jwpaintfgBlink() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamBlink_" "$1")"
}
# --------------------------------------------------------------------------


# ANSI-basic ---------------------------------------------------------------
_jwStyleParamFGRed_="31"
_jwStyleParamFGGreen_="32"
_jwStyleParamFGBrown_="33"
_jwStyleParamFGBlue_="34"
_jwStyleParamFGPurple_="35"
_jwStyleParamFGCyan_="36"
_jwStyleParamFGLightgray_="37"

jwpaintfgRed() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGRed_" "$1")"
}

jwpaintfgGreen() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGGreen_" "$1")"
}

jwpaintfgBrown() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGBrown_" "$1")"
}

jwpaintfgBlue() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGBlue_" "$1")"
}

jwpaintfgPurple() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGPurple_" "$1")"
}

jwpaintfgCyan() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGCyan_" "$1")"
}

jwpaintfgLightgray() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGLightgray_" "$1")"
}
# --------------------------------------------------------------------------


# ANSI-bold ----------------------------------------------------------------
_jwStyleParamFGDarkGray_="1;30"
_jwStyleParamFGLightRed_="1;31"
_jwStyleParamFGLightGreen_="1;32"
_jwStyleParamFGYellow_="1;33"
_jwStyleParamFGLightBlue_="1;34"
_jwStyleParamFGLightPurple_="1;35"
_jwStyleParamFGLightCyan_="1;36"
_jwStyleParamFGWhite_="1;37"

jwpaintfgDarkGray() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGDarkGray_" "$1")"
}

jwpaintfgLightRed() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGLightRed_" "$1")"
}

jwpaintfgLightGreen() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGLightGreen_" "$1")"
}

jwpaintfgYellow() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGYellow_" "$1")"
}

jwpaintfgLightBlue() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGLightBlue_" "$1")"
}

jwpaintfgLightPurple() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGLightPurple_" "$1")"
}

jwpaintfgLightCyan() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGLightCyan_" "$1")"
}

jwpaintfgWhite() {
    printf '%s\n' "$(__jwStylePaintGeneric__ "$_jwStyleParamFGWhite_" "$1")"
}
# --------------------------------------------------------------------------
