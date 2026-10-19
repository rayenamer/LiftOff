# Loads, defaults and validates the app definition.
#
# Every input is an environment variable. An optional .env file supplies them,
# and anything already exported in the real environment wins over the file,
# so `APP_URL=http://localhost:5000 liftoff install app.env` works as expected.

CONFIG_VAR_PATTERN='(APP|DOCKER)_[A-Z0-9_]*'

config::load() {
  local env_file=${1:-}
  APP_ENV_FILE=''

  if [[ -n $env_file ]]; then
    config::source_file "$env_file"
  fi

  config::apply_defaults
  config::validate
}

config::source_file() {
  local env_file=$1
  [[ -f $env_file ]] || die "Env file not found: $env_file"
  APP_ENV_FILE=$(realpath "$env_file")

  # Remember what the caller exported, load the file, then put those back.
  local overrides
  overrides=$(export -p | sed -nE "s/^declare -x ($CONFIG_VAR_PATTERN=)/declare -gx \1/p")

  set -a
  # shellcheck source=/dev/null
  source "$APP_ENV_FILE"
  set +a
  eval "$overrides"

  config::warn_if_exposed
}

config::apply_defaults() {
  [[ -n ${APP_NAME:-} ]] || die "APP_NAME is required"

  # General
  APP_SLUG=${APP_SLUG:-$(slugify "$APP_NAME")}
  APP_MODE=${APP_MODE:-$(config::guess_mode)}
  APP_URL=${APP_URL:-}
  APP_OPEN_BROWSER=${APP_OPEN_BROWSER:-true}
  APP_BROWSER=${APP_BROWSER:-xdg-open}
  APP_WAIT_TIMEOUT=${APP_WAIT_TIMEOUT:-180}
  APP_ICON=${APP_ICON:-utilities-terminal}
  APP_TERMINAL=${APP_TERMINAL:-true}
  APP_DESKTOP_SHORTCUT=${APP_DESKTOP_SHORTCUT:-true}

  # Folder mode
  APP_DIR=${APP_DIR:-}
  APP_INSTALL=${APP_INSTALL:-auto}
  APP_INSTALL_CMD=${APP_INSTALL_CMD:-}
  APP_START_CMD=${APP_START_CMD:-}
  APP_NODE_VERSION=${APP_NODE_VERSION:-}

  # Script mode
  APP_SCRIPT=${APP_SCRIPT:-}
  APP_SCRIPT_ARGS=${APP_SCRIPT_ARGS:-}

  # Container mode
  DOCKER_IMAGE=${DOCKER_IMAGE:-}
  DOCKER_REGISTRY=${DOCKER_REGISTRY:-}
  DOCKER_USERNAME=${DOCKER_USERNAME:-}
  DOCKER_PASSWORD=${DOCKER_PASSWORD:-}
  DOCKER_PASSWORD_FILE=${DOCKER_PASSWORD_FILE:-}
  DOCKER_CONTAINER=${DOCKER_CONTAINER:-liftoff-$APP_SLUG}
  DOCKER_PORTS=${DOCKER_PORTS:-}
  DOCKER_VOLUMES=${DOCKER_VOLUMES:-}
  DOCKER_ENV_FILE=${DOCKER_ENV_FILE:-}
  DOCKER_ARGS=${DOCKER_ARGS:-}
  DOCKER_COMMAND=${DOCKER_COMMAND:-}
  DOCKER_PULL=${DOCKER_PULL:-missing}
  DOCKER_STOP_ON_EXIT=${DOCKER_STOP_ON_EXIT:-true}

  # Relative paths are relative to the env file, not to wherever you ran liftoff.
  APP_DIR=$(config::resolve_path "$APP_DIR")
  APP_SCRIPT=$(config::resolve_path "$APP_SCRIPT")
  DOCKER_ENV_FILE=$(config::resolve_path "$DOCKER_ENV_FILE")
  DOCKER_PASSWORD_FILE=$(config::resolve_path "$DOCKER_PASSWORD_FILE")
  if [[ $APP_ICON == */* ]] && ! is_url "$APP_ICON"; then
    APP_ICON=$(config::resolve_path "$APP_ICON")
  fi
}

config::guess_mode() {
  if   [[ -n ${DOCKER_IMAGE:-} ]]; then echo container
  elif [[ -n ${APP_SCRIPT:-} ]];   then echo script
  else                                  echo folder
  fi
}

config::validate() {
  [[ $APP_MODE =~ ^(folder|script|container)$ ]] || die "APP_MODE must be folder, script or container"
  [[ -z $APP_URL ]] || is_url "$APP_URL" || die "APP_URL must start with http:// or https://"
  [[ $APP_WAIT_TIMEOUT =~ ^[0-9]+$ ]] || die "APP_WAIT_TIMEOUT must be a number of seconds"
  [[ $APP_INSTALL =~ ^(auto|always|never)$ ]] || die "APP_INSTALL must be auto, always or never"

  if [[ $APP_MODE == folder ]]; then
    [[ -n $APP_DIR ]] || die "APP_DIR is required in folder mode"
    [[ -d $APP_DIR ]] || die "APP_DIR does not exist: $APP_DIR"
  elif [[ $APP_MODE == script ]]; then
    [[ -n $APP_SCRIPT ]] || die "APP_SCRIPT is required in script mode"
    [[ -f $APP_SCRIPT ]] || die "APP_SCRIPT does not exist: $APP_SCRIPT"
  else
    [[ -n $DOCKER_IMAGE ]] || die "DOCKER_IMAGE is required in container mode"
    [[ $DOCKER_PULL =~ ^(always|missing|never)$ ]] || die "DOCKER_PULL must be always, missing or never"
    if [[ -n $DOCKER_USERNAME && -z $DOCKER_PASSWORD && -z $DOCKER_PASSWORD_FILE ]]; then
      die "DOCKER_USERNAME is set but neither DOCKER_PASSWORD nor DOCKER_PASSWORD_FILE is"
    fi
  fi
}

config::resolve_path() {
  local path=$1
  if [[ -z $path || $path == /* ]]; then
    printf '%s' "$path"
  elif [[ $path == "~/"* ]]; then
    printf '%s' "$HOME/${path#\~/}"
  else
    printf '%s' "$(dirname "${APP_ENV_FILE:-$PWD/.}")/$path"
  fi
}

# Env files may hold registry passwords; warn if other users can read them.
config::warn_if_exposed() {
  grep -q '^DOCKER_PASSWORD=' "$APP_ENV_FILE" || return 0
  local mode
  mode=$(stat -c '%a' "$APP_ENV_FILE")
  if [[ ${mode: -1} != 0 || ${mode: -2:1} != 0 ]]; then
    log::warn "$APP_ENV_FILE contains a password and is readable by others — run: chmod 600 '$APP_ENV_FILE'"
  fi
}

config::print() {
  local name value
  for name in $(compgen -v | grep -E "^$CONFIG_VAR_PATTERN$" | sort); do
    value=${!name}
    [[ -n $value ]] || continue
    [[ $name == DOCKER_PASSWORD ]] && value='********'
    printf '%-22s %s\n' "$name" "$value"
  done
}
