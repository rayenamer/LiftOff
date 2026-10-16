# Script mode: the app has its own start script, which does its own setup.
#
#   cd to the script's folder -> run it -> wait for URL (if any) -> open browser
#
# Nothing is detected or installed. Everything the script starts, including
# servers it puts in the background, is stopped with the launcher.

script::run() {
  [[ -f $APP_SCRIPT ]] || die "Start script not found: $APP_SCRIPT"
  [[ -n $APP_NODE_VERSION ]] && folder::use_node "$APP_NODE_VERSION"

  log::info "$APP_NAME · script · $APP_SCRIPT"
  cd "$(dirname "$APP_SCRIPT")"

  if [[ -n $APP_URL ]] && url::is_up "$APP_URL"; then
    log::ok "$APP_NAME is already running"
    url::open_browser
    return
  fi

  START_CMD=$(script::command)
  folder::start
}

# Run it directly when it's executable, through bash otherwise.
script::command() {
  if [[ -x $APP_SCRIPT ]]; then
    printf '%q' "$APP_SCRIPT"
  else
    printf 'bash %q' "$APP_SCRIPT"
  fi
}
