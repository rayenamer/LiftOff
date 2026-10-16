# Waiting for the app's URL to answer, and opening it in a browser.

# Any HTTP answer at all (even a 404) means the server is up.
url::is_up() {
  curl -s -o /dev/null --max-time 2 "$1"
}

# url::wait_for <url> <timeout-seconds> <alive-check command...>
# Polls until the URL answers. Gives up early if the alive-check fails,
# so a crashed app doesn't leave you staring at a spinner forever.
url::wait_for() {
  local url=$1 timeout=$2
  shift 2
  local waited=0

  log::info "Waiting for $url (up to ${timeout}s)"
  until url::is_up "$url"; do
    if ! "$@" 2>/dev/null; then
      log::error "$APP_NAME stopped before $url came up"
      return 1
    fi
    if ((waited >= timeout)); then
      log::error "Timed out after ${timeout}s waiting for $url"
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
  done
  log::ok "$APP_NAME is up at $url"
}

url::open_browser() {
  [[ -n $APP_URL ]] && is_true "$APP_OPEN_BROWSER" || return 0
  log::info "Opening $APP_URL"
  # APP_BROWSER is split on purpose so it can carry flags, e.g. "brave-browser --new-window".
  # shellcheck disable=SC2086
  setsid $APP_BROWSER "$APP_URL" >/dev/null 2>&1 &
}
