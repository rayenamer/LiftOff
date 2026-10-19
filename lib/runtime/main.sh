# Entry point of every generated launcher.
#
# The app runs in a subshell so its own EXIT traps (stopping servers and
# containers) fire before the window is held open for reading.

run_app() {
  local status
  set +e
  (
    set -e
    case $APP_MODE in
      folder)    folder::run ;;
      script)    script::run ;;
      container) container::run ;;
      *)         die "Unknown APP_MODE: $APP_MODE" ;;
    esac
  )
  status=$?
  set -e

  hold_window "$status"
  return "$status"
}

# Launched from an icon, the terminal closes as soon as the launcher exits —
# including when a start script backgrounds its services and returns, or on
# an error. Keep it open until Enter so the output can be read.
hold_window() {
  is_true "$APP_TERMINAL" && [[ -t 0 ]] || return 0
  if (($1 == 0)); then
    log::ok "$APP_NAME launcher finished"
  else
    log::error "$APP_NAME launcher exited with status $1"
  fi
  read -rp "Press Enter to close this window… " _ || true
}
