#!/usr/bin/env bash
# Lint + format checks for GuineaMPEG: Rust (rustfmt/clippy), QML (qmllint/qmlformat),
# C++ (clang-format/clang-tidy).
#
# Usage:
#   $0                          Run all lint + format checks (fails on any violation)
#   $0 --fix                    Auto-apply formatters (rustfmt, clang-format, clippy --fix),
#                               then re-run the checks to verify (never touches qmlformat)
#   $0 --only <rust|cpp|qml>    Limit to one language
#   $0 --format                 Also run the qmlformat equality check (opt-in: qmlformat
#                               output differs across Qt versions, so it is skipped by default)
#   $0 --format-fix             Auto-apply qmlformat -i -f, then run the equality check
#   $0 --cpp-tidy               Also run clang-tidy (configures out/.build-lint)
#   $0 --help                   Show this help message
set -euo pipefail

show_help() {
    cat <<EOF
Run the GuineaMPEG lint + format checks: Rust (rustfmt/clippy), QML (qmllint/qmlformat),
C++ (clang-format/clang-tidy).

Usage:
  $0                          Run all lint + format checks (fails on any violation)
  $0 --fix                    Auto-apply formatters, then re-run the checks
  $0 --only <rust|cpp|qml>    Limit to one language
  $0 --format                 Also run the qmlformat equality check (opt-in: qmlformat
                              output differs across Qt versions, so it is skipped by default)
  $0 --format-fix             Auto-apply qmlformat -i -f, then run the equality check
  $0 --cpp-tidy               Also run clang-tidy (configures out/.build-lint)
  $0 --help                   Show this help message
EOF
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUST_DIR="${ROOT}/rust"
LINT_BUILD_DIR="${ROOT}/out/.build-lint"

MODE=check
ONLY=
FORMAT=false
FORMAT_FIX=false
CPP_TIDY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix) MODE=fix; shift ;;
        --only) ONLY="${2:?--only needs <rust|cpp|qml>}"; shift 2 ;;
        --format) FORMAT=true; shift ;;
        --format-fix) FORMAT_FIX=true; FORMAT=true; shift ;;
        --cpp-tidy) CPP_TIDY=true; shift ;;
        --help) show_help; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1 ;;
    esac
done

case "$ONLY" in
    "" | rust | cpp | qml) ;;
    *) echo "Invalid --only value: $ONLY (expected rust|cpp|qml)" >&2; exit 1 ;;
esac

FAILED=0
fail() { FAILED=1; }

CPP_FILES=()
while IFS= read -r -d '' f; do CPP_FILES+=("$f"); done < <(
    find "${ROOT}/src" "${ROOT}/tests/cpp" \( -name '*.cpp' -o -name '*.h' \) -print0
)

QML_FILES=()
QML_ONLY=()
while IFS= read -r -d '' f; do QML_FILES+=("$f"); done < <(
    find "${ROOT}/qml" "${ROOT}/tests/qml" \( -name '*.qml' -o -name '*.js' \) -print0
)
while IFS= read -r -d '' f; do QML_ONLY+=("$f"); done < <(
    find "${ROOT}/qml" "${ROOT}/tests/qml" -name '*.qml' -print0
)

# Qt's own QML module directories (QtQuick & co.) so qmllint can resolve them
# even when its built-in install-path lookup doesn't cover the distro layout
# (e.g. Debian multiarch /usr/lib/<triplet>/qt6/qml in CI).
QT_QML_IMPORT_DIRS=()
for d in /usr/lib/qt6/qml /usr/lib/*/qt6/qml /usr/lib64/qt6/qml; do
    if [[ -d "$d" ]]; then
        QT_QML_IMPORT_DIRS+=("$d")
    fi
done

resolve_tool() {
    local name="$1" result=""
    local d
    for d in /usr/lib64/qt6/bin /usr/lib/qt6/bin /usr/lib/*/qt6/bin; do
        if [[ -x "$d/$name" ]]; then result="$d/$name"; break; fi
    done
    if [[ -z "$result" ]]; then
        result="$(command -v "${name}-qt6" 2>/dev/null || true)"
    fi
    if [[ -z "$result" ]]; then
        result="$(command -v "$name" 2>/dev/null || true)"
    fi
    printf '%s' "$result"
}
QMLLINT="$(resolve_tool qmllint)"
QMLFORMAT="$(resolve_tool qmlformat)"

rust_section() {
    echo "==> Rust (rustfmt + clippy)"
    if [[ $MODE == fix ]]; then
        (cd "${RUST_DIR}" && cargo fmt --all)
        (cd "${RUST_DIR}" && cargo clippy --all-targets --fix --allow-dirty)
    fi
    if ! (cd "${RUST_DIR}" && cargo fmt --all -- --check); then
        echo "!! Rust: formatting violations (run './build/run-lint.sh --fix')"
        fail
    fi
    if ! (cd "${RUST_DIR}" && cargo clippy --all-targets -- -D warnings); then
        echo "!! Rust: clippy warnings"
        fail
    fi
}

qml_section() {
    echo "==> QML (qmllint + qmlformat)"
    if [[ ${#QML_FILES[@]} -eq 0 ]]; then
        echo "!! QML: no files found"
        fail
        return
    fi
    if [[ -z "$QMLLINT" ]]; then
        echo "!! QML: qmllint not found (install the Qt6 QML tooling)"
        fail
        return
    fi
    if [[ $FORMAT_FIX == true ]]; then
        if [[ -z "$QMLFORMAT" ]]; then
            echo "!! QML: qmlformat not found (install the Qt6 QML tooling)"
            fail
            return
        fi
        "$QMLFORMAT" -i -f "${QML_ONLY[@]}"
    fi
    local -a qmllint_args=(-I "${ROOT}/qml")
    local d
    for d in "${QT_QML_IMPORT_DIRS[@]}"; do
        qmllint_args+=(-I "$d")
    done
    local qmllint_output qmllint_status=0
    qmllint_output="$("$QMLLINT" "${qmllint_args[@]}" "${QML_FILES[@]}" 2>&1)" || qmllint_status=$?
    if [[ $qmllint_status -ne 0 || -n "$qmllint_output" ]]; then
        printf '%s\n' "$qmllint_output" >&2
        echo "!! QML: qmllint emitted errors, warnings or info messages"
        fail
    fi
    if [[ $FORMAT != true ]]; then
        return
    fi
    if [[ -z "$QMLFORMAT" ]]; then
        echo "!! QML: qmlformat not found (install the Qt6 QML tooling)"
        fail
        return
    fi
    local unformatted=0 f
    for f in "${QML_ONLY[@]}"; do
        if ! cmp -s <("$QMLFORMAT" "$f") "$f"; then
            echo "!! QML: not formatted: ${f}"
            unformatted=1
        fi
    done
    if [[ $unformatted -eq 1 ]]; then
        echo "!! QML: formatting violations (run './build/run-lint.sh --fix')"
        fail
    fi
}

cpp_tidy() {
    echo "==> C++ (clang-tidy)"
    local tidy_srcs=() f
    for f in "${CPP_FILES[@]}"; do
        case "$f" in
            "${ROOT}/src/"*.cpp) tidy_srcs+=("$f") ;;
        esac
    done
    if [[ ${#tidy_srcs[@]} -eq 0 ]]; then
        echo "!! clang-tidy: no src/*.cpp files"
        fail
        return
    fi
    if [[ ! -f "${LINT_BUILD_DIR}/compile_commands.json" ]]; then
        echo "==> configuring ${LINT_BUILD_DIR} (compile_commands.json)"
        cmake -S "${ROOT}" -B "${LINT_BUILD_DIR}" \
            -DCMAKE_CXX_COMPILER="${CMAKE_CXX_COMPILER:-clang++}" \
            -DCMAKE_BUILD_TYPE=Debug -DPACKAGE_TARGET=generic \
            -DBUILD_TESTING=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON >/dev/null
    fi
    if ! clang-tidy -p "${LINT_BUILD_DIR}" "${tidy_srcs[@]}"; then
        echo "!! C++: clang-tidy warnings"
        fail
    fi
}

cpp_section() {
    echo "==> C++ (clang-format)"
    if [[ ${#CPP_FILES[@]} -eq 0 ]]; then
        echo "!! C++: no files found"
        fail
        return
    fi
    if [[ $MODE == fix ]]; then
        clang-format -i "${CPP_FILES[@]}"
    fi
    if ! clang-format --dry-run --Werror "${CPP_FILES[@]}"; then
        echo "!! C++: formatting violations (run './build/run-lint.sh --fix')"
        fail
    fi
    if $CPP_TIDY; then
        cpp_tidy
    fi
}

if [[ -z $ONLY || $ONLY == rust ]]; then rust_section; fi
if [[ -z $ONLY || $ONLY == qml ]]; then qml_section; fi
if [[ -z $ONLY || $ONLY == cpp ]]; then cpp_section; fi

if [[ $FAILED -ne 0 ]]; then
    echo
    echo "==> FAILED: fix with './build/run-lint.sh --fix'"
    exit 1
fi
echo "==> OK"