# Folder mode: run an app straight from its project directory.
#
#   detect stack -> install deps if they changed -> start -> wait for URL -> open browser
#
# The app runs in its own process group, so stopping the launcher (Ctrl+C or
# closing the terminal) stops the whole tree — dev servers, watchers and all.
# folder::start and folder::use_node are shared with script mode.

folder::run() {
  [[ -n $APP_NODE_VERSION ]] && folder::use_node "$APP_NODE_VERSION"

  stack::detect "$APP_DIR"
  [[ -n $START_CMD ]] || die "Can't tell how to start $APP_DIR — set APP_START_CMD"
  log::info "$APP_NAME · $STACK · $APP_DIR"
  cd "$APP_DIR"

  if [[ -n $APP_URL ]] && url::is_up "$APP_URL"; then
    log::ok "$APP_NAME is already running"
    url::open_browser
    return
  fi

  folder::install_deps
  folder::start
}

folder::start() {
  log::info "Starting: $START_CMD"
  setsid bash -c "$START_CMD" &
  APP_PID=$!

  trap folder::stop EXIT
  trap 'exit 130' INT TERM HUP

  if [[ -n $APP_URL ]]; then
    url::wait_for "$APP_URL" "$APP_WAIT_TIMEOUT" folder::is_alive || exit 1
    url::open_browser
  fi

  log::info "Running. Press Ctrl+C or close this window to stop."
  wait "$APP_PID" || true

  # Start scripts that background their server and exit leave it running in
  # the same process group — keep watching until that is gone too.
  while folder::is_alive; do sleep 1; done

  # Services detached elsewhere (e.g. `docker compose up -d`) outlive the
  # process group; with a stop command, hold until the window is closed.
  if [[ -n $APP_STOP_CMD ]]; then
    while :; do sleep 1; done
  fi
}

# True while anything started by START_CMD is still running, not just the
# command itself.
folder::is_alive() {
  kill -0 -- "-$APP_PID" 2>/dev/null
}

folder::stop() {
  if folder::is_alive; then
    log::info "Stopping $APP_NAME" 2>/dev/null || true
    kill -TERM -- "-$APP_PID" 2>/dev/null || true
  fi
  folder::run_stop_cmd
}

# Detached from the terminal and logged to a file, so it still finishes when
# the window was closed and the tty is already gone.
folder::run_stop_cmd() {
  [[ -n $APP_STOP_CMD ]] || return 0
  local log_file
  log_file="$(app_state_dir)/stop.log"
  log::info "Stopping: $APP_STOP_CMD" 2>/dev/null || true
  setsid bash -c "$APP_STOP_CMD" </dev/null >>"$log_file" 2>&1 &
  wait $! || log::warn "Stop command failed — see $log_file" 2>/dev/null || true
}

folder::install_deps() {
  [[ -n $INSTALL_CMD && $APP_INSTALL != never ]] || return 0

  local stamp_file current_stamp
  stamp_file="$(app_state_dir)/deps.sha256"
  current_stamp=$(folder::deps_fingerprint)

  if [[ $APP_INSTALL == auto && -f $stamp_file && $(<"$stamp_file") == "$current_stamp" ]]; then
    log::ok "Dependencies are up to date"
    return
  fi

  log::info "Installing dependencies: $INSTALL_CMD"
  bash -c "$INSTALL_CMD" || die "Dependency install failed"

  # Installing can create a lockfile (and so change what we detect); fingerprint the result.
  stack::detect "$APP_DIR"
  folder::deps_fingerprint >"$stamp_file"
  log::ok "Dependencies installed"
}

# Changes when the install command or deps file changes, or the deps folder is deleted.
folder::deps_fingerprint() {
  {
    printf '%s\n' "$INSTALL_CMD"
    if [[ -n $DEPS_DIR && -d $DEPS_DIR ]]; then printf 'deps-dir present\n'; fi
    if [[ -n $DEPS_FILE && -f $DEPS_FILE ]]; then cat "$DEPS_FILE"; fi
  } | sha256sum | cut -d' ' -f1
}

# Put a specific nvm-installed Node first on PATH, without sourcing nvm itself.
folder::use_node() {
  local bin="${NVM_DIR:-$HOME/.nvm}/versions/node/v${1#v}/bin"
  [[ -x $bin/node ]] || die "Node $1 is not installed via nvm (looked in $bin)"
  export PATH="$bin:$PATH"
  log::info "Using Node $(node --version)"
}
