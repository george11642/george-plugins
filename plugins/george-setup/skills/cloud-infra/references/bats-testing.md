# BATS Testing Patterns Reference

Detailed patterns for shell script testing with BATS. Parent skill: [../SKILL.md](../SKILL.md)

## Installation

```bash
brew install bats-core          # macOS
npm install --global bats       # via npm
# or clone https://github.com/bats-core/bats-core.git
```

### Helper Libraries

Install these for richer assertions:

```bash
# bats-support + bats-assert (recommended)
git clone https://github.com/bats-core/bats-support tests/test_helper/bats-support
git clone https://github.com/bats-core/bats-assert tests/test_helper/bats-assert
# bats-file: file/directory assertions
git clone https://github.com/bats-core/bats-file tests/test_helper/bats-file
```

Load all three at the top of every test file (bats-support must come first as it is a dependency):

```bash
#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/bats-file/load'

@test "assert_output example" {
    run echo "hello world"
    assert_success
    assert_output --partial "world"
}

@test "assert_file_exists example" {
    touch "$BATS_TEST_TMPDIR/result.txt"
    assert_file_exists "$BATS_TEST_TMPDIR/result.txt"
    assert_file_permission 644 "$BATS_TEST_TMPDIR/result.txt" || true
}
```

Note: `BATS_TEST_TMPDIR` is automatically created and cleaned up per-test by bats-core. Prefer it over manual `mktemp -d` in `setup()` when isolation is the only goal.

## Project Structure

```
project/
  bin/script.sh
  tests/
    test_script.bats
    test_helper.sh
    fixtures/
    helpers/mocks.bash
    test_helper/
      bats-support/
      bats-assert/
```

## Basic Test File

```bash
#!/usr/bin/env bats

load test_helper

setup() { export TMPDIR=$(mktemp -d); }
teardown() { rm -rf "$TMPDIR"; }

@test "function returns 0 on success" {
    run my_function "input"
    [ "$status" -eq 0 ]
}

@test "function outputs correct result" {
    run my_function "test"
    [ "$output" = "expected output" ]
}

@test "function returns 1 on missing argument" {
    run my_function
    [ "$status" -eq 1 ]
}
```

## Assertion Patterns

### Exit Codes

```bash
@test "success" { run true; [ "$status" -eq 0 ]; }
@test "failure" { run false; [ "$status" -ne 0 ]; }
@test "specific code" { run my_func --invalid; [ "$status" -eq 127 ]; }
```

### Output

```bash
@test "exact match" { run echo "hello"; [ "$output" = "hello" ]; }
@test "contains" { run echo "hello world"; [[ "$output" == *"world"* ]]; }
@test "regex" { result=$(date +%Y); [[ "$result" =~ ^[0-9]{4}$ ]]; }
@test "lines" {
    run printf "a\nb\nc"
    [ "${lines[0]}" = "a" ]
    [ "${lines[1]}" = "b" ]
}
```

### With bats-assert (Richer Output on Failure)

```bash
@test "assert patterns" {
    run echo "hello world"
    assert_success                    # status == 0
    assert_output "hello world"       # exact match
    assert_output --partial "world"   # substring
    assert_output --regexp "^hello"   # regex
    assert_line --index 0 "hello world"
}

@test "failure patterns" {
    run false
    assert_failure                    # status != 0
    assert_failure 1                  # specific exit code
}

@test "refute patterns" {
    run echo "hello"
    refute_output --partial "error"   # must NOT contain
}
```

### Files

```bash
@test "file created" {
    my_function > "$TMPDIR/out.txt"
    [ -f "$TMPDIR/out.txt" ]
}

@test "file contents" {
    my_function > "$TMPDIR/out.txt"
    [ "$(cat "$TMPDIR/out.txt")" = "expected" ]
}

@test "file size" {
    echo -n "12345" > "$TMPDIR/test.txt"
    [ "$(wc -c < "$TMPDIR/test.txt")" -eq 5 ]
}
```

### File Permission Assertions (Cross-Platform)

`stat` has different flag syntax on Linux vs macOS. Use a helper to abstract it:

```bash
# In test_helper.sh
get_file_perms() {
    local file="$1"
    if stat --version &>/dev/null 2>&1; then
        # GNU stat (Linux)
        stat -c '%a' "$file"
    else
        # BSD stat (macOS)
        stat -f '%OLp' "$file"
    fi
}

@test "script is executable" {
    chmod 755 "$TMPDIR/script.sh"
    local perms
    perms=$(get_file_perms "$TMPDIR/script.sh")
    [ "$perms" = "755" ]
}

@test "config has restricted permissions" {
    echo "secret" > "$TMPDIR/config"
    chmod 600 "$TMPDIR/config"
    local perms
    perms=$(get_file_perms "$TMPDIR/config")
    [ "$perms" = "600" ]
}
```

## Setup / Teardown

### Per-Test (Isolation)

```bash
setup() {
    TEST_DIR=$(mktemp -d)
    source "${BATS_TEST_DIRNAME}/../bin/script.sh"
}
teardown() { rm -rf "$TEST_DIR"; }
```

### Per-File (Expensive Resources)

```bash
setup_file() {
    export SHARED=$(mktemp -d)
    echo "data" > "$SHARED/data.txt"
}
teardown_file() { rm -rf "$SHARED"; }
```

## Mocking and Stubbing

### Function Mock

```bash
my_external_tool() { echo "mocked output"; return 0; }

@test "uses mocked tool" {
    export -f my_external_tool
    run my_function
    [[ "$output" == *"mocked"* ]]
}
```

### PATH-Based Command Stub

Create executable stubs that shadow real commands -- the most reliable mocking pattern:

```bash
setup() {
    STUBS="$TMPDIR/stubs"; mkdir -p "$STUBS"
    export PATH="$STUBS:$PATH"
}

create_stub() {
    local cmd="$1" output="$2" code="${3:-0}"
    cat > "$STUBS/$cmd" <<EOF
#!/bin/bash
echo "$output"
exit $code
EOF
    chmod +x "$STUBS/$cmd"
}

@test "stubbed curl" {
    create_stub curl '{"status":"ok"}' 0
    run my_api_function
    [ "$status" -eq 0 ]
}
```

### Spy Pattern (Record Calls)

Verify that a command was called with specific arguments:

```bash
create_spy() {
    local cmd="$1"
    cat > "$STUBS/$cmd" <<'EOF'
#!/bin/bash
echo "$0 $*" >> "$STUBS/.call_log"
EOF
    chmod +x "$STUBS/$cmd"
}

@test "function calls curl with correct URL" {
    create_spy curl
    run my_function
    grep -q "curl.*https://api.example.com" "$STUBS/.call_log"
}
```

### Environment Override

```bash
@test "env override" {
    export MY_SETTING="override"
    run my_function
    [[ "$output" == *"override"* ]]
}

@test "uses default" {
    unset MY_SETTING
    run my_function
    [[ "$output" == *"default"* ]]
}
```

## Fixtures

### Static Fixtures

```bash
setup() {
    FIXTURES="${BATS_TEST_DIRNAME}/fixtures"
    WORK=$(mktemp -d)
}
teardown() { rm -rf "$WORK"; }

@test "process fixture" {
    cp "$FIXTURES/input.txt" "$WORK/input.txt"
    run process "$WORK/input.txt"
    diff "$WORK/output.txt" "$FIXTURES/expected.txt"
}
```

### Dynamic Fixture Generation

```bash
generate_fixture() {
    local lines="$1" file="$2"
    for i in $(seq 1 "$lines"); do
        echo "Line $i content" >> "$file"
    done
}

@test "handles large input" {
    generate_fixture 1000 "$TMPDIR/large.txt"
    run my_function "$TMPDIR/large.txt"
    [ "$status" -eq 0 ]
}
```

### Fixture Directories

```bash
# Create a complete directory tree for integration tests
setup() {
    WORK=$(mktemp -d)
    mkdir -p "$WORK"/{src,out,config}
    echo '{"debug": true}' > "$WORK/config/settings.json"
    echo "data" > "$WORK/src/input.csv"
}
```

## Conditional Skip

```bash
@test "needs jq" {
    command -v jq &>/dev/null || skip "jq not installed"
    run parse_json '{"k":"v"}'
    [ "$status" -eq 0 ]
}

@test "linux only" {
    [[ "$(uname)" == "Linux" ]] || skip "requires Linux"
    run my_linux_function
    [ "$status" -eq 0 ]
}
```

### skip_if Helper

Define a `skip_if` helper for more readable conditional skipping:

```bash
# In test_helper.sh or setup():
skip_if() {
    if "$@" 2>/dev/null; then
        skip "condition met: $*"
    fi
}
# skip_if returns non-zero = condition NOT met = do not skip
# Invert: skip when a condition is FALSE
skip_unless() {
    if ! "$@" 2>/dev/null; then
        skip "requirement not met: $*"
    fi
}

@test "JSON parsing" {
    skip_unless command -v jq
    run my_parser '{"key": "value"}'
    [ "$status" -eq 0 ]
}

@test "root-only operation" {
    skip_unless [ "$(id -u)" -eq 0 ]
    run my_privileged_function
    [ "$status" -eq 0 ]
}
```

## Shell Compatibility

```bash
@test "works in bash" { bash "$SCRIPT" arg1; }
@test "works in sh"   { sh "$SCRIPT" arg1; }
@test "works in dash" {
    command -v dash &>/dev/null || skip "dash not installed"
    dash "$SCRIPT" arg1
}
```

## Testing Error Messages

Verify that scripts produce helpful error output:

```bash
@test "missing arg shows usage" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "invalid option shows error" {
    run "$SCRIPT" --bogus
    [ "$status" -ne 0 ]
    [[ "${lines[0]}" == *"ERROR"* ]]
    [[ "$output" == *"Usage:"* ]]
}

@test "stderr contains error, stdout is clean" {
    run bash -c '"$SCRIPT" --invalid 2>/tmp/stderr'
    [ -s /tmp/stderr ]  # stderr is non-empty
}
```

## Test Helper (test_helper.sh)

```bash
#!/usr/bin/env bash
export SCRIPT_DIR="${BATS_TEST_DIRNAME%/*}/bin"

assert_file_exists() { [ -f "$1" ] || { echo "Missing: $1"; return 1; }; }
assert_file_equals() {
    local actual=$(cat "$1")
    [ "$actual" = "$2" ] || { echo "Expected: $2, Got: $actual"; return 1; }
}
assert_line_count() {
    local file="$1" expected="$2"
    local actual=$(wc -l < "$file")
    [ "$actual" -eq "$expected" ] || { echo "Lines: expected $expected, got $actual"; return 1; }
}
setup_test_dir() { export TEST_DIR=$(mktemp -d); }
cleanup_test_dir() { rm -rf "$TEST_DIR"; }
```

## CI Integration

### GitHub Actions

```yaml
steps:
  - uses: actions/checkout@v4
  - run: npm install --global bats
  - run: bats tests/*.bats --tap
```

### Makefile

```makefile
test:          bats tests/*.bats
test-verbose:  bats tests/*.bats --verbose-run
test-parallel: bats tests/*.bats --jobs 4
test-tap:      bats tests/*.bats --tap
test-filter:   bats tests/*.bats --filter "$(PATTERN)"
```

## Best Practices

1. One assertion focus per test
2. Descriptive test names stating expected behavior
3. Always clean up in teardown
4. Test both success and failure paths
5. Mock external commands for isolation -- prefer PATH stubs over function mocks
6. Use fixtures for complex test data
7. Run in CI with TAP output
8. Use `--jobs` for parallel speed
9. Skip tests when dependencies are missing
10. Keep test helpers DRY in test_helper.sh
11. Use bats-assert for readable failure messages
12. Test error messages, not just exit codes
