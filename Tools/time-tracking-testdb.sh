#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Roland Foerther
#
# Time Tracking test database: build it and, if wanted, swap it in for the
# database of the Developer variant (ported from Tagwerk's testdata/testdb.sh).
#
#   Tools/time-tracking-testdb.sh             generate the test data and build
#                                             build/testdata/timetracking.db
#   Tools/time-tracking-testdb.sh --install   also replace the app's database with
#                                             the test database (backed up first)
#   Tools/time-tracking-testdb.sh --restore   bring back the newest backup with real data
#   Tools/time-tracking-testdb.sh -h|--help   show this text
#
# The test data always end yesterday (18 full months plus the current month, see
# Tools/time-tracking-testdata.py) and are generated anew on every call, together
# with their Markdown source build/testdata/testdata.md and the generator's report
# build/testdata/report.txt (build/ is not in the repository). They hold work away
# from the Mac and rule violations, about 10 % days with more than 6 h without a
# break, holidays, 30 vacation days and 6 days of time off in lieu a year as
# absences, a day of special leave every six months and 4-6 h of work on the
# Saturday of the week before.
#
# Database: ~/Library/Application Support/<bundle id>/TimeTracking/timetracking.db
#   BARFORGE_BUNDLE_ID  bundle id of the app (default de.foerther.barforge.dev, the
#                       Developer variant of ./build.sh --dev); the release app
#                       de.foerther.barforge only with --allow-release
#   BARFORGE_TT_DIR     another data folder instead (for trying this out without any
#                       app container); then no app is quit unless
#                       BARFORGE_BUNDLE_ID is set as well
# Backups: <data folder>/before-testdata/timetracking-YYYY-MM-DD_HHMMSS.db
#
# A running app is quit before the swap and opened again afterwards. The test
# database carries the row settings('barforge_testdata', 1). A database with that
# row is not backed up again, and --restore skips backups with it, so the real
# data always come back. --restore refuses to overwrite a database with real data.
set -euo pipefail

MODE="build"
ALLOW_RELEASE=0
for arg in "$@"; do
  case "$arg" in
    --install) MODE="install" ;;
    --restore) MODE="restore" ;;
    --allow-release) ALLOW_RELEASE=1 ;;
    -h|--help) awk 'NR >= 5 && /^#/ { sub(/^# ?/, ""); print; next } NR >= 5 { exit }' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
TEST_DIR="$ROOT/build/testdata"
TEST_DB="$TEST_DIR/timetracking.db"
TEST_MD="$TEST_DIR/testdata.md"
TEST_REPORT="$TEST_DIR/report.txt"
RELEASE_ID="de.foerther.barforge"
BUNDLE_ID="${BARFORGE_BUNDLE_ID:-de.foerther.barforge.dev}"
if [[ -n "${BARFORGE_TT_DIR:-}" ]]; then
  DATA_DIR="$BARFORGE_TT_DIR"
  # Another data folder: the app does not use it, so leave the app alone unless
  # the bundle id was given explicitly as well.
  [[ -n "${BARFORGE_BUNDLE_ID:-}" ]] && CONTROL_APP=1 || CONTROL_APP=0
else
  DATA_DIR="$HOME/Library/Application Support/$BUNDLE_ID/TimeTracking"
  CONTROL_APP=1
fi
APP_DB="$DATA_DIR/timetracking.db"
SAFE_DIR="$DATA_DIR/before-testdata"
# Marker row of the test database in `settings`; Barforge only upserts its own keys.
TEST_KEY="barforge_testdata"
# Schema of TimeTrackingDatabase (schemaVersion) the generator writes.
SCHEMA_VERSION=3

# Database files and their folders are owner-only, as Barforge keeps them.
umask 077

step() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

command -v sqlite3 >/dev/null || fail "sqlite3 not found."

# Makes a database file self-contained (no -wal/-shm) and checks it. Barforge
# switches back to WAL itself when it opens the database.
seal() {
  local db="$1"
  sqlite3 "$db" "PRAGMA journal_mode=DELETE;" >/dev/null || return 1
  rm -f "$db-wal" "$db-shm"
  [[ "$(sqlite3 "$db" 'PRAGMA integrity_check')" == "ok" ]] || return 1
  rm -f "$db-wal" "$db-shm"
}

# Does the file hold test data?
is_test_db() {
  [[ "$(sqlite3 "$1" "SELECT value FROM settings WHERE key = '$TEST_KEY'" 2>/dev/null)" == "1" ]]
}

# ---------- Build the test database -------------------------------------------

build_test_db() {
  command -v python3 >/dev/null || fail "python3 not found."
  mkdir -p "$TEST_DIR"
  step "Generating test data up to yesterday"
  rm -f "$TEST_DB.new"
  python3 "$HERE/time-tracking-testdata.py" --db "$TEST_DB.new" > "$TEST_MD" 2> "$TEST_REPORT" \
    || { cat "$TEST_REPORT" >&2; fail "The generator failed."; }
  head -1 "$TEST_REPORT"
  step "Checking $TEST_DB"
  local version blocks
  version="$(sqlite3 "$TEST_DB.new" 'PRAGMA user_version')"
  [[ "$version" == "$SCHEMA_VERSION" ]] \
    || fail "The generator wrote schema $version, Barforge expects schema $SCHEMA_VERSION."
  blocks="$(sqlite3 "$TEST_DB.new" 'SELECT count(*) FROM work_blocks')"
  [[ "$blocks" -gt 0 ]] || fail "The test database holds no work away from the Mac."
  is_test_db "$TEST_DB.new" || fail "The test database lacks its marker row."
  seal "$TEST_DB.new" || fail "The test database is damaged."
  rm -f "$TEST_DB-wal" "$TEST_DB-shm"
  mv -f "$TEST_DB.new" "$TEST_DB"
  echo "$(sqlite3 "$TEST_DB" 'SELECT count(DISTINCT date) FROM periods') days," \
    "$(sqlite3 "$TEST_DB" 'SELECT count(DISTINCT date) FROM work_blocks') with work away from the Mac" \
    "($(sqlite3 "$TEST_DB" "SELECT min(date) || ' to ' || max(date) FROM periods"))," \
    "$(sqlite3 "$TEST_DB" 'SELECT count(*) FROM absences') absences"
  echo "Markdown source: $TEST_MD"
  echo "Report:          $TEST_REPORT"
}

# ---------- The running app ------------------------------------------------------

guard_release() {
  if [[ "$BUNDLE_ID" == "$RELEASE_ID" && "$ALLOW_RELEASE" != 1 ]]; then
    fail "$BUNDLE_ID is the release app; pass --allow-release to touch its data."
  fi
}

# The app's LaunchServices id (ASN:0x...-0x...), empty when it does not run.
app_asn() {
  lsappinfo find "bundleid=$BUNDLE_ID" 2>/dev/null | sed -nE 's/^(ASN:[^-]+-[^-:]+).*/\1/p' | head -1
}

app_running() {
  [[ -n "$(app_asn)" ]]
}

app_info() {
  local asn
  asn="$(app_asn)"
  [[ -n "$asn" ]] && lsappinfo info -only "$1" "$asn" 2>/dev/null || true
}

app_pid() {
  app_info pid | sed -nE 's/.*"?pid"? ?= ?([0-9]+).*/\1/p' | head -1
}

app_path() {
  app_info bundlepath | sed -nE 's/.*bundle ?path"? ?= ?"([^"]*)".*/\1/p' | head -1
}

# Processes that have the database open.
db_users() {
  local f files=()
  for f in "$APP_DB" "$APP_DB-wal" "$APP_DB-shm"; do
    if [[ -e "$f" ]]; then files+=("$f"); fi
  done
  [[ ${#files[@]} -gt 0 ]] || return 0
  lsof -t "${files[@]}" 2>/dev/null | sort -u | paste -sd ' ' - || true
}

WAS_RUNNING=0
APP_PATH=""

stop_app() {
  if [[ "$CONTROL_APP" == 1 ]] && app_running; then
    step "Quitting $BUNDLE_ID"
    WAS_RUNNING=1
    # Remembered to open the same copy again (build/stage or /Applications).
    APP_PATH="$(app_path)"
    # A regular quit, so the running recording is saved.
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null \
      || fail "$BUNDLE_ID did not accept the quit (PID $(app_pid)) - quit it by hand."
    local i
    for i in $(seq 1 40); do
      app_running || break
      sleep 0.25
    done
    if app_running; then fail "$BUNDLE_ID keeps running (PID $(app_pid)) - quit it by hand."; fi
  fi
  local i users=""
  for i in $(seq 1 20); do
    users="$(db_users)"
    [[ -z "$users" ]] && return 0
    sleep 0.25
  done
  fail "The database is still open (PID $users) - close that process first."
}

reopen_app() {
  [[ "$WAS_RUNNING" == 1 ]] || return 0
  step "Opening $BUNDLE_ID again"
  if [[ -n "$APP_PATH" && -d "$APP_PATH" ]]; then
    open "$APP_PATH" && return 0
  fi
  open -b "$BUNDLE_ID" || echo "Could not open $BUNDLE_ID; start it by hand." >&2
}

# ---------- Swap -------------------------------------------------------------------

replace_app_db() {
  local source="$1"
  cp "$source" "$APP_DB.new"
  chmod 600 "$APP_DB.new"
  rm -f "$APP_DB-wal" "$APP_DB-shm"
  mv -f "$APP_DB.new" "$APP_DB"
}

install_test_db() {
  [[ -f "$TEST_DB" ]] || fail "$TEST_DB is missing."
  mkdir -p "$DATA_DIR"
  chmod 700 "$DATA_DIR"
  stop_app
  if [[ -f "$APP_DB" ]] && is_test_db "$APP_DB"; then
    step "The database already holds test data - no new backup"
  elif [[ -f "$APP_DB" ]]; then
    mkdir -p "$SAFE_DIR"
    chmod 700 "$SAFE_DIR"
    local backup
    backup="$SAFE_DIR/timetracking-$(date +%Y-%m-%d_%H%M%S).db"
    [[ -e "$backup" ]] && fail "$backup exists already - try again in a second."
    step "Backing up the database to $backup"
    sqlite3 "$APP_DB" ".backup '$backup'" \
      || fail "The backup failed - the database stays as it is."
    seal "$backup" || fail "The backup is incomplete - the database stays as it is."
    chmod 600 "$backup"
  fi
  step "Replacing $APP_DB with the test database"
  replace_app_db "$TEST_DB"
  reopen_app
  echo
  echo "The test database is active. Back to the real data: Tools/time-tracking-testdb.sh --restore"
}

restore_app_db() {
  if [[ -f "$APP_DB" ]] && ! is_test_db "$APP_DB"; then
    fail "$APP_DB holds real data, not test data - nothing to restore."
  fi
  # the newest backup without test data
  local latest="" f
  while IFS= read -r f; do
    if [[ -n "$f" ]] && ! is_test_db "$f"; then
      latest="$f"
      break
    fi
  done < <(ls -1 "$SAFE_DIR"/timetracking-*.db 2>/dev/null | sort -r)
  [[ -n "$latest" ]] || fail "No backup with real data in $SAFE_DIR."
  seal "$latest" || fail "$latest is damaged."
  stop_app
  step "Restoring $APP_DB from $(basename "$latest")"
  replace_app_db "$latest"
  reopen_app
  echo
  echo "The real data are active again. The backup stays in $SAFE_DIR."
}

case "$MODE" in
  build)   build_test_db ;;
  install) guard_release; build_test_db; install_test_db ;;
  restore) guard_release; restore_app_db ;;
esac

step "Done"
