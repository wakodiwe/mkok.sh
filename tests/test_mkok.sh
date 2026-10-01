#!/usr/bin/env sh
# test_mkok.sh - Unit tests for mkok.sh 
#
# Usage: sh test_mkok.sh
# The harness under test is sourced, then its functions (assert_*, run,
# group_*, discover_tests, run_shellcheck, ...) are exercised directly.
#
# Notes:
#   * ShellCheck is disabled so the suite runs without that dependency.
#   * OKSH_COLOR=false keeps the status markers plain, which makes exact
#     output assertions easier. Colour behaviour is tested separately.
#   * Functions that would corrupt the outer pass/fail counters (fail, and the
#     failure branches of the assertions) are called inside command
#     substitutions so each runs in a throw-away subshell.

# OKSH_SHELLCHECK=false
# OKSH_COLOR=false
OKSH_VERBOSE=true

SCRIPT=./hello.sh

MKOK_SH="../src/mkok.sh"
# shellcheck source=/dev/null
. "$MKOK_SH"

# Fail if $2 does not... rather, fail if $1 IS found in $2.
assert_not_contains() {
    case "$2" in
        *"$1"*) fail "${3:-not_contains} (unexpectedly found '$1')" ;;
        *) pass "${3:-not_contains}" ;;
    esac
}

# Source mkok.sh from scratch in a clean subshell and print one variable.
fresh_var() {
    (
        unset OKSH_SH_SOURCED OKSH_VERBOSE OKSH_SHELLCHECK \
            OKSH_SHELLCHECK_FORMAT OKSH_SHELLCHECK_NORC \
            OKSH_GROUP OKSH_GROUP_LINE OKSH_INFO_LINE OKSH_TOTAL_LINE \
            OKSH_COLOR OKSH_GROUP_CHAR OKSH_INFO_CHAR OKSH_FAILED_CHAR \
            OKSH_PASSED_CHAR SOURCE
        # shellcheck source=/dev/null
        . "$MKOK_SH" >/dev/null 2>&1
        eval "printf '%s' \"\${$1:-}\""
    )
}

# Write a small fixture used by the discovery tests.

build_fixture() {
    _g='group'
    _t='test_'
    {
        printf '%s alpha\n' "$_g"
        printf '%s alpha_a() {\n:\n}\n' "$_t"
        printf '%s alpha_b() {\n:\n}\n' "$_t"
        printf '%s beta\n' "$_g"
        printf '%s beta_a() {\n:\n}\n' "$_t"
    } > ./_fixture_disc.sh
}
trap 'rm -f ./_fixture_disc.sh' EXIT

# --- ASSERTIONS ---
group ASSERTIONS

test_assert_eq_passes_on_equal() {
    _o=$( OKSH_VERBOSE=true; assert_eq "abc" "abc" "eq-ok" 2>&1 )
    assert_contains "eq-ok" "$_o" "assert_eq logs the check name on success"
}

test_assert_eq_fails_on_difference() {
    _o=$( assert_eq "abc" "xyz" "eq-bad" 2>&1 )
    assert_contains "eq-bad" "$_o" "assert_eq names a failing check"
    assert_contains "wanted 'abc'" "$_o" "assert_eq reports the expected value"
    assert_contains "actual 'xyz'" "$_o" "assert_eq reports the actual value"
}

test_assert_eq_default_name() {
    _o=$( assert_eq "1" "2" 2>&1 )
    assert_contains "eq" "$_o" "assert_eq falls back to name 'eq'"
}

test_assert_contains_passes() {
    _o=$( OKSH_VERBOSE=true; assert_contains "ell" "hello" "has-ok" 2>&1 )
    assert_contains "has-ok" "$_o" "assert_contains logs the check name"
}

test_assert_contains_fails() {
    _o=$( assert_contains "z" "hello" "has-bad" 2>&1 )
    assert_contains "has-bad" "$_o" "assert_contains names a failing check"
    assert_contains "not found" "$_o" "assert_contains reports the missing needle"
}

test_assert_contains_default_name() {
    _o=$( assert_contains "z" "hello" 2>&1 )
    assert_contains "contains" "$_o" "assert_contains falls back to 'contains'"
}

test_assert_exit_passes() {
    _ret=0
    _o=$( OKSH_VERBOSE=true; assert_exit 0 "exit-ok" 2>&1 )
    assert_contains "exit-ok" "$_o" "assert_exit logs the check name"
}

test_assert_exit_fails() {
    _ret=7
    _o=$( assert_exit 2 "exit-bad" 2>&1 )
    assert_contains "exit-bad" "$_o" "assert_exit names a failing check"
    assert_contains "expected 2" "$_o" "assert_exit reports the expected code"
    assert_contains "got 7" "$_o" "assert_exit reports the actual code"
}

test_assert_exit_default_name() {
    _ret=1
    _o=$( assert_exit 0 2>&1 )
    assert_contains "exit" "$_o" "assert_exit falls back to name 'exit'"
}

test_pass_and_fail_update_counters() {
    _p=$( _passed=0; _total=0; pass x >/dev/null 2>&1; printf '%s/%s' "$_passed" "$_total" )
    assert_eq "1/1" "$_p" "pass increments _passed and _total"
    _f=$( _failed=0; _total=0; fail x >/dev/null 2>&1; printf '%s/%s' "$_failed" "$_total" )
    assert_eq "1/1" "$_f" "fail increments _failed and _total"
}

test_fail_message_uses_marker() {
    _o=$( _failed=0; _total=0; fail boom 2>&1 )
    assert_contains "boom" "$_o" "fail includes the message"
    assert_contains "$OKSH_FAILED_CHAR" "$_o" "fail prefixes the failed marker"
}

test_msg_interprets_escape_sequences() {
    _exp=$( printf 'a\nb' )
    _o=$( msg 'a\nb' 2>&1 )
    assert_eq "$_exp" "$_o" "msg expands %b escape sequences"
}

test_log_honours_verbose_flag() {
    _quiet=$( OKSH_VERBOSE=false; log hidden 2>&1 )
    assert_eq "" "$_quiet" "log is silent when OKSH_VERBOSE=false"
    _loud=$( OKSH_VERBOSE=true; log shown 2>&1 )
    assert_eq "shown" "$_loud" "log emits when OKSH_VERBOSE=true"
}

# --- EXECUTION ---
group EXECUTION

test_run_captures_stdout_and_exit() {
    SCRIPT=./hello.sh
    run
    assert_eq "hello, world" "$_out" "run captures stdout with default arg"
    assert_exit 0 "run records exit status 0"
}

test_run_forwards_arguments() {
    SCRIPT=./hello.sh
    run Ada
    assert_eq "hello, Ada" "$_out" "run forwards positional arguments"
}

test_run_records_nonzero_exit() {
    SCRIPT=./exit3.sh
    run
    SCRIPT=./hello.sh
    assert_exit 3 "run records a non-zero exit status"
}

test_run_merges_stderr_into_out() {
    SCRIPT=./mixed.sh
    run
    SCRIPT=./hello.sh
    assert_contains "stdout line" "$_out" "run keeps the target's stdout"
    assert_contains "stderr line" "$_out" "run merges the target's stderr"
}

test_run_clears_previous_output() {
    SCRIPT=./empty.sh
    _out="stale"
    run
    SCRIPT=./hello.sh
    assert_eq "" "$_out" "run resets _out before executing"
}

test_run_source_mode() {
    _so=$SOURCE
    SOURCE=true
    SCRIPT=./hello.sh
    run Ada
    SOURCE=$_so
    assert_eq "hello, Ada" "$_out" "SOURCE=true sources the target in-shell"
    assert_exit 0 "sourced target exit status is captured"
}

# --- GROUPING ---
group GROUPING

test_group_disable_adds_name() {
    _d=$( OKSH_DISABLED=' '; group_disable slow; printf '%s' "$OKSH_DISABLED" )
    assert_eq " slow " "$_d" "group_disable stores a padded group name"
}

test_group_enable_removes_name() {
    _e=$( OKSH_DISABLED=' slow fast '; group_enable slow; printf '%s' "$OKSH_DISABLED" )
    assert_eq " fast " "$_e" "group_enable strips the padded group name"
}

test_group_is_enabled_result() {
    _on=$( OKSH_DISABLED=' '; group_is_enabled fast; printf '%s' "$?" )
    assert_eq "0" "$_on" "known group -> exit 0"
    _off=$( OKSH_DISABLED=' slow '; group_is_enabled slow; printf '%s' "$?" )
    assert_eq "1" "$_off" "disabled group -> exit 1"
}

test_group_name_maps_spaces_and_keeps() {
    _n=$( OKSH_GROUP=default; group_name "a b c"; printf '%s' "$OKSH_GROUP" )
    assert_eq "a_b_c" "$_n" "group_name replaces spaces with underscores"
    _k=$( OKSH_GROUP=keep; group_name ""; printf '%s' "$OKSH_GROUP" )
    assert_eq "keep" "$_k" "group_name with empty input keeps OKSH_GROUP"
}

test_group_dispatches_subcommands() {
    _d=$( OKSH_DISABLED=' '; group disable alpha; printf '%s' "$OKSH_DISABLED" )
    assert_eq " alpha " "$_d" "group disable -> group_disable"
    # shellcheck disable=SC2031,SC2030
    _e=$( OKSH_DISABLED=' alpha beta '; group enable alpha; printf '%s' "$OKSH_DISABLED" )
    assert_eq " beta " "$_e" "group enable -> group_enable"
    _n=$( OKSH_GROUP=old; group mylabel; printf '%s' "$OKSH_GROUP" )
    assert_eq "mylabel" "$_n" "group NAME -> group_name"
}

# --- CONFIGURATION ---
group CONFIGURATION

test_configuration_defaults() {
    assert_eq "false"   "$(fresh_var OKSH_VERBOSE)"           "OKSH_VERBOSE defaults to false"
    assert_eq "true"    "$(fresh_var OKSH_SHELLCHECK)"        "OKSH_SHELLCHECK defaults to true"
    assert_eq "tty"     "$(fresh_var OKSH_SHELLCHECK_FORMAT)" "OKSH_SHELLCHECK_FORMAT defaults to tty"
    assert_eq "false"   "$(fresh_var OKSH_SHELLCHECK_NORC)"   "OKSH_SHELLCHECK_NORC defaults to false"
    assert_eq "default" "$(fresh_var OKSH_GROUP)"             "OKSH_GROUP defaults to default"
    assert_eq "true"    "$(fresh_var OKSH_COLOR)"             "OKSH_COLOR defaults to true"
    assert_eq ">>>"     "$(fresh_var OKSH_INFO_CHAR)"         "OKSH_INFO_CHAR defaults to >>>"
    assert_eq "---"     "$(fresh_var OKSH_FAILED_CHAR)"       "OKSH_FAILED_CHAR defaults to ---"
    assert_eq "+++"     "$(fresh_var OKSH_PASSED_CHAR)"       "OKSH_PASSED_CHAR defaults to +++"
    assert_eq "false"   "$(fresh_var SOURCE)"                 "SOURCE defaults to false"
}

# The source line is ': "${OKSH_GROUP_CHAR:====}"'.  Although it reads like
# four '=', POSIX parses ':=' after the colon as the assign-if-unset operator
# and takes '===' as the word, so the effective default is the documented
# three-character '===' (consistent with the other markers).  Confusingly
# written, but correct -- this test pins that behaviour down.
test_group_char_default_is_three_equals() {
    assert_eq "===" "$(fresh_var OKSH_GROUP_CHAR)" "OKSH_GROUP_CHAR defaults to '==='"
}

test_color_wraps_markers() {
    assert_contains "[33m" "$(fresh_var _group_char)"  "group marker is coloured yellow"
    assert_contains "[34m" "$(fresh_var _info_char)"   "info marker is coloured blue"
    assert_contains "[31m" "$(fresh_var _failed_char)" "failed marker is coloured red"
    assert_contains "[32m" "$(fresh_var _passed_char)" "passed marker is coloured green"
}

test_no_color_leaves_plain_markers() {
    _v=$(
        unset OKSH_SH_SOURCED OKSH_COLOR OKSH_GROUP_CHAR
        OKSH_COLOR=false
        # shellcheck source=/dev/null
        . "$MKOK_SH" >/dev/null 2>&1
        printf '%s' "$_group_char"
    )
    assert_eq "===" "$_v" "OKSH_COLOR=false keeps an uncoloured group marker"
}

test_sourcing_guard_is_idempotent() {
    _v=$( _passed=999; # shellcheck source=/dev/null
          . "$MKOK_SH" >/dev/null 2>&1; printf '%s' "$_passed" )
    assert_eq "999" "$_v" "re-sourcing does not reset counters (guard works)"
}

# --- DISCOVERY ---
group DISCOVERY

test_discover_tests_lists_groups_and_tests() {
    build_fixture
    _old_tf=$TESTFILE
    # shellcheck disable=SC2031
    _old_dis=${OKSH_DISABLED:-}
    TESTFILE=./_fixture_disc.sh
    OKSH_DISABLED=' '
    _got=$(discover_tests | tr '\n' ' ')
    TESTFILE=$_old_tf
    OKSH_DISABLED=$_old_dis
    assert_contains "alpha_a" "$_got" "discovers test in first group"
    assert_contains "alpha_b" "$_got" "discovers second test in first group"
    assert_contains "beta_a"  "$_got" "discovers test in second group"
    assert_contains "alpha"   "$_got" "emits the first group header"
    assert_contains "beta"    "$_got" "emits the second group header"
}

test_discover_tests_skips_disabled_group() {
    build_fixture
    _old_tf=$TESTFILE
    _old_dis=${OKSH_DISABLED:-}
    TESTFILE=./_fixture_disc.sh
    OKSH_DISABLED=' beta '
    _got=$(discover_tests | tr '\n' ' ')
    TESTFILE=$_old_tf
    OKSH_DISABLED=$_old_dis
    assert_contains "alpha_a" "$_got" "enabled group is still discovered"
    assert_not_contains "beta_a" "$_got" "disabled group is skipped"
}

# --- RUNNER ---
group RUNNER

test_shellcheck_disabled_is_noop() {
    _old=$OKSH_SHELLCHECK
    OKSH_SHELLCHECK=false
    # Run in a subshell so we can observe both the exit status and the change
    # to the pass counter without the surrounding assertions interfering.
    _res=$( _passed=0; run_shellcheck 2>/dev/null; printf '%s:%s' "$?" "$_passed" )
    OKSH_SHELLCHECK=$_old
    assert_eq "0:0" "$_res" "run_shellcheck disabled returns 0 and counts nothing"
}

test_run_tests_requires_script() {
    _o=$( unset SCRIPT; run_tests 2>/dev/null )
    _rc=$?
    assert_eq "1" "$_rc" "run_tests exits 1 when SCRIPT is unset"
}

# --- FAIL ---
group FAIL
test_fail() {
    assert_eq "true" "false" "false is true!"
}

run_tests
