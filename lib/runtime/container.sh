# Container mode: log in to a registry, pull an image and run it.
#
#   login (if credentials given) -> pull -> run -> wait for URL -> open browser -> follow logs
#
# Closing the terminal or pressing Ctrl+C stops the container (DOCKER_STOP_ON_EXIT).
# The registry password is only ever piped to `docker login --password-stdin`.

container::run() {
  require_cmd docker
  log::info "$APP_NAME · container · $DOCKER_IMAGE"

  if container::is_running; then
    log::ok "$APP_NAME is already running ($DOCKER_CONTAINER)"
    url::open_browser
    return
  fi

  container::login
  container::pull
  container::start

  trap container::stop EXIT
  trap 'exit 130' INT TERM HUP

  if [[ -n $APP_URL ]]; then
    url::wait_for "$APP_URL" "$APP_WAIT_TIMEOUT" container::is_running || {
      docker logs --tail 30 "$DOCKER_CONTAINER" >&2
      exit 1
    }
    url::open_browser
  fi

  log::info "Running. Press Ctrl+C or close this window to stop."
  docker logs -f "$DOCKER_CONTAINER"
}

container::login() {
  [[ -n $DOCKER_USERNAME ]] || return 0

  local registry password
  registry=$(container::registry)
  password=$DOCKER_PASSWORD
  [[ -n $DOCKER_PASSWORD_FILE ]] && password=$(<"$DOCKER_PASSWORD_FILE")

  log::info "Logging in to ${registry:-Docker Hub} as $DOCKER_USERNAME"
  printf '%s' "$password" \
    | docker login ${registry:+"$registry"} --username "$DOCKER_USERNAME" --password-stdin >/dev/null \
    || die "Registry login failed"
}

# DOCKER_REGISTRY if given, otherwise taken from the image name
# ("ghcr.io/me/app:1.0" -> "ghcr.io"); empty means Docker Hub.
container::registry() {
  if [[ -n $DOCKER_REGISTRY ]]; then
    printf '%s' "$DOCKER_REGISTRY"
    return
  fi
  local first=${DOCKER_IMAGE%%/*}
  if [[ $DOCKER_IMAGE == */* && ($first == *.* || $first == *:* || $first == localhost) ]]; then
    printf '%s' "$first"
  fi
}

container::pull() {
  case $DOCKER_PULL in
    never) return ;;
    missing) docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1 && return ;;
  esac
  log::info "Pulling $DOCKER_IMAGE"
  docker pull "$DOCKER_IMAGE" || die "Pull failed"
}

container::start() {
  # A stopped container from a previous run would block the name; replace it
  # so config changes (ports, env, image) always take effect.
  docker rm -f "$DOCKER_CONTAINER" >/dev/null 2>&1 || true

  local args=(run --detach --name "$DOCKER_CONTAINER" --label "liftoff.app=$APP_SLUG")
  local port volume extra command

  for port in $DOCKER_PORTS; do args+=(--publish "$port"); done
  for volume in $DOCKER_VOLUMES; do args+=(--volume "$volume"); done
  [[ -n $DOCKER_ENV_FILE ]] && args+=(--env-file "$DOCKER_ENV_FILE")

  read -ra extra <<<"$DOCKER_ARGS"
  read -ra command <<<"$DOCKER_COMMAND"
  args+=("${extra[@]}" "$DOCKER_IMAGE" "${command[@]}")

  log::info "Starting container $DOCKER_CONTAINER"
  docker "${args[@]}" >/dev/null || die "docker run failed"
}

container::stop() {
  is_true "$DOCKER_STOP_ON_EXIT" || return 0
  container::is_running || return 0
  log::info "Stopping $DOCKER_CONTAINER"
  docker stop "$DOCKER_CONTAINER" >/dev/null || true
}

container::is_running() {
  [[ $(docker inspect -f '{{.State.Running}}' "$DOCKER_CONTAINER" 2>/dev/null) == true ]]
}
