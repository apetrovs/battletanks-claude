#!/usr/bin/env bash
# Import check, unit tests and a headless smoke run of the main scene.
# Godot only prints script problems; it does not fail the process, so each step's output is
# also scanned for error markers.
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG_DIR="${TMPDIR:-/tmp}/tank-battle-checks"
mkdir -p "$LOG_DIR"

# Sandboxes that cannot write to the Godot user dir produce these harmless errors.
NOISE='app_userdata|user://|Library/Caches/Godot|Library/Application Support/Godot|editor settings|Can.t save resource to empty path|get_system_ca_certificates|ret != noErr|editor_doc_cache'
BAD='SCRIPT ERROR|Parse Error|Failed to load script|ERROR:'

# Prints offending log lines; "   at: " continuation lines of an ignored error are skipped too.
scan_log() {
	awk -v noise="$NOISE" -v bad="$BAD" '
		$0 ~ noise { skip = 1; next }
		/^[[:space:]]+at: / { if (skip) next }
		{ skip = 0 }
		$0 ~ bad { print }
	' "$1"
}

overall=0
declare -a summary=()

run_step() {
	local name="$1"; shift
	local log="$LOG_DIR/$name.log"
	local rc=0
	"$@" >"$log" 2>&1 || rc=$?
	local problems
	problems="$(scan_log "$log")"
	if [[ $rc -ne 0 || -n "$problems" ]]; then
		echo "--- $name: output (exit code $rc) ---"
		if [[ -n "$problems" ]]; then
			echo "$problems"
		else
			tail -n 40 "$log"
		fi
		summary+=("FAIL  $name (log: $log)")
		overall=1
	else
		summary+=("PASS  $name")
	fi
	if [[ "$name" == "tests" ]]; then
		grep -E '^(FAIL|ERROR) |^[0-9]+ passed' "$log" || true
		grep -A5 '^FAIL ' "$log" | grep '^      ' || true
	fi
}

run_step import "$GODOT" --headless --path . --import
run_step tests "$GODOT" --headless --path . --script res://tests/test_runner.gd
run_step smoke "$GODOT" --headless --path . --quit-after 900

echo
echo "=== check summary ==="
printf '%s\n' "${summary[@]}"
if [[ $overall -eq 0 ]]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit $overall
