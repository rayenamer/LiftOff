# Shared helpers: logging, small predicates, and where Liftoff keeps its own files.

LIFTOFF_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/liftoff"
LIFTOFF_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/liftoff"

if [[ -t 2 ]]; then
  C_RESET=$'\e[0m' C_BLUE=$'\e[34m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_RED=$'\e[31m'
else
  C_RESET='' C_BLUE='' C_GREEN='' C_YELLOW='' C_RED=''
fi

# Logs go to stderr so stdout stays usable for data.
log::info()  { printf '%s▸%s %s\n' "$C_BLUE" "$C_RESET" "$*" >&2; }
log::ok()    { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*" >&2; }
log::warn()  { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log::error() { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

die() {
  log::error "$*"
  exit 1
}

is_true() {
  [[ ${1,,} =~ ^(1|true|yes|on)$ ]]
}

is_url() {
  [[ $1 =~ ^https?:// ]]
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed"
}

# "My Cool App" -> "my-cool-app"
slugify() {
  local slug=${1,,}
  slug=${slug//[^a-z0-9]/-}
  while [[ $slug == *--* ]]; do slug=${slug//--/-}; done
  slug=${slug#-}
  printf '%s' "${slug%-}"
}

# Per-app folder for Liftoff's bookkeeping (dependency stamps etc.).
app_state_dir() {
  local dir="$LIFTOFF_STATE_DIR/$APP_SLUG"
  mkdir -p "$dir"
  printf '%s' "$dir"
}
