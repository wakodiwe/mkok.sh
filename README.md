## mkok.sh

Minimal POSIX shell test harness.  Single file. No dependencies.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/wakodiwe/mkok.sh/refs/heads/main/install.sh | sh
```

Installs to `~/.local/lib/mkok.sh` by default.

Override with `PREFIX`:

```sh
curl -fsSL https://raw.githubusercontent.com/wakodiwe/mkok.sh/refs/heads/main/install.sh | PREFIX=/usr/local sh
```

Or just copy `mkok.sh` into your project and source it directly.

## Usage

```sh
#!/usr/bin/env sh

. ./mkok.sh        # or . ~/.local/lib/ok.sh after install

SCRIPT=./myscript.sh

test_help() {
    run --help
        assert_exit 0 "--help exits 0"
        assert_contains "Usage:" "$_out" "--help shows usage"
}

test_version() {
    run --version
        assert_exit 0 "--version exits 0"
        assert_contains "1.0.0" "$_out" "--version shows version"
}

run_tests
```

```
-- Test: ./myscript.sh
+ shellcheck
+ --help exits 0
+ --help shows usage
+ --version exits 0
+ --version shows version

4 run, 0 failed
```

## API

### Running

| Function | Description |
|---|---|
| `run [ARGS...]` | Execute `$SCRIPT` with args, capture output in `$_out` and exit code in `$_ret` |
| `run_tests` | Auto-discover and run all `test_*` functions, print summary |

### Assertions

| Function | Description |
|---|---|
| `assert_exit EXP [NAME]` | Assert `$_ret` equals `EXP` |
| `assert_eq EXP ACT [NAME]` | Assert two strings are equal |
| `assert_contains NEEDLE HAY [NAME]` | Assert `HAY` contains `NEEDLE` |

### Environment

| Variable | Default | Description |
|---|---|---|
| `SCRIPT` | *(required)* | Path to the script under test |
| `SOURCE` | `false` | Source `$SCRIPT` instead of executing it |
| `TEST_VERBOSE` | `false` | Print passing assertions too |

## Requirements

- POSIX sh (dash, bash, etc.)
    - `shellcheck` optional - skipped if not found

## License

    BSD
