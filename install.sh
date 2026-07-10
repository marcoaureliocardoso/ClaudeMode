#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SOURCE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX=${PREFIX:-$HOME/.local}

if [[ -z "$PREFIX" || "$PREFIX" == "/" ]]; then
  printf 'Refusing unsafe PREFIX: %s\n' "$PREFIX" >&2
  exit 2
fi

case "$PREFIX" in
  /*) ;;
  *)
    printf 'PREFIX must be an absolute path: %s\n' "$PREFIX" >&2
    exit 2
    ;;
esac

LIB_DIR="$PREFIX/lib/claude-mode"
BIN_DIR="$PREFIX/bin"
WRAPPER="$BIN_DIR/claude-mode"

if [[ "${1:-}" == "--uninstall" ]]; then
  case "$LIB_DIR" in
    */lib/claude-mode) ;;
    *)
      printf 'Refusing unsafe library path: %s\n' "$LIB_DIR" >&2
      exit 2
      ;;
  esac
  rm -f "$WRAPPER"
  rm -rf -- "$LIB_DIR"
  printf 'Removed %s and %s\n' "$WRAPPER" "$LIB_DIR"
  exit 0
fi

mkdir -p "$LIB_DIR/bin" "$LIB_DIR/lib" "$BIN_DIR"
cp "$SOURCE_DIR/bin/claude-mode" "$LIB_DIR/bin/claude-mode"
cp "$SOURCE_DIR/lib/"*.sh "$SOURCE_DIR/lib/json_tool.py" "$LIB_DIR/lib/"
chmod 700 "$LIB_DIR/bin/claude-mode" "$LIB_DIR/lib/json_tool.py"
chmod 600 "$LIB_DIR/lib/"*.sh

cat > "$WRAPPER" <<EOF_WRAPPER
#!/usr/bin/env bash
exec "$LIB_DIR/bin/claude-mode" "\$@"
EOF_WRAPPER
chmod 700 "$WRAPPER"

printf 'Installed claude-mode at %s\n' "$WRAPPER"
printf 'Add %s to PATH when necessary.\n' "$BIN_DIR"
