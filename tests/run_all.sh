#!/usr/bin/env bash

# Unified test runner: creates/uses venv, installs test deps, runs all tests.
# Usage:
#   tests/run_all.sh [--base-url http://localhost:8081] [--skip-persistence] [--no-compose]

set -u

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
VENVBIN="$ROOT_DIR/.venv/bin"
PY_BIN="$VENVBIN/python"
PIP_BIN="$VENVBIN/pip"

BASE_URL_DEFAULT="http://localhost:8081"
BASE_URL="$BASE_URL_DEFAULT"
SKIP_PERSISTENCE=1
USE_COMPOSE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      BASE_URL="${2}"; shift 2;;
    --skip-persistence)
      SKIP_PERSISTENCE=1; shift;;
    --no-compose)
      USE_COMPOSE=0; shift;;
    *)
      echo "Unknown option: $1"; shift;;
  esac
done

detect_port() {
  # Prefer builds/.env FASTAPI_EXTERNAL_PORT
  if [[ -f "$ROOT_DIR/builds/.env" ]]; then
    local p=$(grep -E '^FASTAPI_EXTERNAL_PORT=' "$ROOT_DIR/builds/.env" | tail -n1 | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    if [[ -n "$p" ]]; then echo "$p"; return 0; fi
  fi
  echo "8081"
}

PORT=$(detect_port)
BASE_URL=${BASE_URL:-"http://localhost:${PORT}"}
WS_URL="ws://localhost:${PORT}/ws"

ensure_venv() {
  if [[ ! -x "$PY_BIN" ]]; then
    echo "Creating virtual environment at $ROOT_DIR/.venv ..."
    python3 -m venv "$ROOT_DIR/.venv" || { echo "Failed to create venv"; exit 1; }
  fi
}

install_test_deps() {
  echo "Installing test dependencies (requests, websockets) ..."
  "$PIP_BIN" install --upgrade pip >/dev/null 2>&1 || true
  "$PIP_BIN" install requests>=2.31.0 websockets==12.0 || { echo "Failed to install test deps"; exit 1; }
}

compose_up() {
  if [[ "$USE_COMPOSE" -eq 1 ]]; then
    if command -v docker >/dev/null 2>&1; then
      echo "Ensuring containers are up (docker compose up -d) ..."
      (cd "$ROOT_DIR/builds" && docker compose up -d) || echo "Skipping compose up"
    fi
  fi
}

health_check() {
  echo "Health check at ${BASE_URL}/health ..."
  local code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health" 2>/dev/null || echo "000")
  echo "HTTP ${code}"
}

run_test() {
  local name="$1"; shift
  echo "----------------------------------------"
  echo "Running: ${name}"
  set +e
  "$PY_BIN" "$@"
  local rc=$?
  set -e
  echo "Exit code: ${rc}"
  return ${rc}
}

main() {
  ensure_venv
  install_test_deps
  compose_up
  health_check

  failures=0

  run_test "Common endpoints" "$ROOT_DIR/tests/test_health.py" --base-url "${BASE_URL}" || failures=$((failures+1))
  run_test "Manual RAG" "$ROOT_DIR/tests/test_manual_rag.py" --base-url "${BASE_URL}" || failures=$((failures+1))
  run_test "LangChain RAG (basic)" "$ROOT_DIR/tests/test_langchain_rag_basic.py" --base-url "${BASE_URL}" || failures=$((failures+1))
  run_test "Agents API" "$ROOT_DIR/tests/test_agents.py" --base-url "${BASE_URL}" || failures=$((failures+1))
  run_test "WebSocket Chat" "$ROOT_DIR/tests/test_websocket_chat.py" --ws-url "${WS_URL}" || failures=$((failures+1))

  # Chroma comprehensive test, default skip persistence
  if [[ "$SKIP_PERSISTENCE" -eq 1 ]]; then
    run_test "Chroma (no persistence)" "$ROOT_DIR/tests/test_chroma.py" --base-url "${BASE_URL}" --skip-persistence || failures=$((failures+1))
  else
    run_test "Chroma (with persistence)" "$ROOT_DIR/tests/test_chroma.py" --base-url "${BASE_URL}" || failures=$((failures+1))
  fi

  echo "========================================"
  echo "Test suite completed. Failures: ${failures}"
  echo "========================================"
  exit ${failures}
}

main
