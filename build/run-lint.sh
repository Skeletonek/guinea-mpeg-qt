#!/usr/bin/env bash
# Lint + format checks for GuineaMPEG: Rust (rustfmt/clippy), QML (qmllint/qmlformat),
# C++ (clang-format/clang-tidy).
#
# Usage:
#   $0                          Run all lint + format checks (fails on any violation)
#   $0 --fix                    Auto-apply formatters (rustfmt, qmlformat, clang-format,
#                               clippy --fix), then re-run the checks to verify
#   $0 --only <rust|cpp|qml>    Limit to one language
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
  $0 --cpp-tidy               Also run clang-tidy (configures out/.build-lint)
  $0 --help                   Show this help message
EOF
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUST_DIR="${ROOT}/rust"
LINT_BUILD_DIR="${ROOT}/out/.build-lint"

MODE=check
ONLY=
CPP_TIDY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix) MODE=fix; shift ;;
        --only) ONLY="${2:?--only needs <rust|cpp|qml>}"; shift 2 ;;
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
    if [[ $MODE == fix ]]; then
        qmlformat -i -f "${QML_ONLY[@]}"
    fi
    if ! qmllint -I "${ROOT}/qml" "${QML_FILES[@]}"; then
        echo "!! QML: qmllint errors"
        fail
    fi
    local unformatted=0 f
    for f in "${QML_ONLY[@]}"; do
        if ! cmp -s <(qmlformat "$f") "$f"; then
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