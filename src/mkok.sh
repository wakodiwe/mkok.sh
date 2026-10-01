#!/usr/bin/env sh
# mkok.sh - Minimal POSIX shell test harness.
# Version: 0.0.0

[ -n "${OKSH_SH_SOURCED:-}" ] \
    && return 0 2> /dev/null || true
OKSH_SH_SOURCED=true

: "${OKSH_VERBOSE:=false}"

: "${OKSH_SHELLCHECK:=true}"
: "${OKSH_SHELLCHECK_FORMAT:=tty}"
: "${OKSH_SHELLCHECK_NORC:=false}"

: "${OKSH_GROUP:=default}"

: "${OKSH_GROUP_LINE:=true}"
: "${OKSH_INFO_LINE:=true}"
: "${OKSH_TOTAL_LINE:=true}"

: "${OKSH_COLOR:=true}"
: "${OKSH_GROUP_CHAR:====}"
: "${OKSH_INFO_CHAR:=>>>}"
: "${OKSH_FAILED_CHAR:=---}"
: "${OKSH_PASSED_CHAR:=+++}"

: "${SOURCE:=false}"

case $0 in
    /*) TESTFILE=$0 ;;
    *) TESTFILE=$PWD/$0 ;;
esac

_info_char="$OKSH_INFO_CHAR"
_group_char="$OKSH_GROUP_CHAR"
_failed_char="$OKSH_FAILED_CHAR"
_passed_char="$OKSH_PASSED_CHAR"
if [ "$OKSH_COLOR" = true ]; then
    _group_char="\033[33m${OKSH_GROUP_CHAR}\033[0m"
    _info_char="\033[34m${OKSH_INFO_CHAR}\033[0m"
    _failed_char="\033[31m${OKSH_FAILED_CHAR}\033[0m"
    _passed_char="\033[32m${OKSH_PASSED_CHAR}\033[0m"
fi

_failed=0
_passed=0
_total=0

msg() {
    printf "%b\n" "$*" >&2
}

log() {
    [ "${OKSH_VERBOSE}" != false ] \
        && msg "${*}"
}

fail() {
    msg "${_failed_char} $*"
    _failed=$((_failed + 1))
    _total=$((_total + 1))
}

pass() {
    log "${_passed_char} $*"
    _passed=$((_passed + 1))
    _total=$((_total + 1))
}

assert_contains() {
    _needle="$1"
    _hay="$2"
    _name="$3"
    case "$_hay" in
        *"$_needle"*) pass "$_name" ;;
        *) fail "${_name:-contains}\n    -> '$_needle' not found)" ;;
    esac
}

assert_eq() {
    _exp="$1"
    _act="$2"
    _name="$3"
    if [ "$_exp" = "$_act" ]; then
        pass "$_name"
    else
        fail "${_name:-eq}\n    -> wanted '$_exp'\n    -> actual '$_act'"
    fi
}

assert_exit() {
    _exp="$1"
    _name="$2"
    if [ "$_ret" -eq "$_exp" ]; then
        pass "$_name"
    else
        fail "${_name:-exit} (expected $_exp, got $_ret)"
    fi
}

run() {
    _out=
    if [ "$SOURCE" = true ]; then
        # shellcheck source=/dev/null
        _out=$(
            set -- "$@"
            . "$SCRIPT" 2>&1
        )
        _ret=$?
    else
        _out=$(sh "$SCRIPT" "$@" 2>&1)
        _ret=$?
    fi
}

group_disable() {
    for _g in "$@"; do
        case "${OKSH_DISABLED:- }" in
            *" $_g "*) ;;
            *) OKSH_DISABLED="${OKSH_DISABLED:- }${_g} " ;;
        esac
    done
}

group_enable() {
    for _g in "$@"; do
        OKSH_DISABLED=$(
            printf '%s' "${OKSH_DISABLED:- }" \
                | sed "s/ $_g / /g"
        )
    done
}

group_is_enabled() {
    case "${OKSH_DISABLED:- }" in
        *" $1 "*) return 1 ;;
        *) return 0 ;;
    esac
}

group_name() {
    _name="$(
        printf '%s' "$*" \
            | tr ' ' '_'
    )"
    OKSH_GROUP="${_name:-$OKSH_GROUP}"
}

group() {
    case "$1" in
        disable)
            shift
            group_disable "$@"
            ;;
        enable)
            shift
            group_enable "$@"
            ;;
        *)
            group_name "$*"
            ;;
    esac
}

run_shellcheck() {
    [ "$OKSH_SHELLCHECK" = false ] \
        && return

    [ "$OKSH_SHELLCHECK_NORC" = false ] \
        && _norc="--norc "

    if _res="$(
        shellcheck \
            ${_norc:-} \
            -f "${OKSH_SHELLCHECK_FORMAT:?not defined}" \
            -s sh \
            -x $SCRIPT
    )"; then
        pass "shellcheck $SCRIPT"
    else
        # shellcheck disable=SC2181
        [ $? -gt 1 ] \
            && exit 1
        fail "shellcheck $SCRIPT"
        msg "$_res"
        exit 1
    fi
}

discover_tests() {
    while IFS= read -r line; do
        case "$line" in
            'group '*)
                _group=${line#group }
                group_is_enabled "${_group:- }" \
                    && printf '%s\n' "$_group"
                ;;
            'test_'*'()'*)
                ! group_is_enabled "${_group:- }" \
                    && continue
                printf '%s\n' "${line%%()*}"
                ;;
        esac
    done < "$TESTFILE"
}

run_tests() {
    [ -z "${SCRIPT:-}" ] && {
        log "SCRIPT not set"
        exit 1
    }

    [ "$OKSH_INFO_LINE" = true ] \
        && log "$_info_char $0 -> $SCRIPT"

    run_shellcheck

    for t in $(discover_tests); do
        if [ "${t%%_*}" = "test" ]; then
            $t
            continue
        fi
        [ "$OKSH_GROUP_LINE" = true ] \
            && log "$_group_char $t"
    done

    [ "$OKSH_TOTAL_LINE" = true ] \
        && msg "$_passed_char $_total run, $_failed failed"

    [ "$_failed" -eq 0 ]
}
