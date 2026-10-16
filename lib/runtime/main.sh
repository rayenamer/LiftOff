# Entry point of every generated launcher.

run_app() {
  case $APP_MODE in
    folder)    folder::run ;;
    script)    script::run ;;
    container) container::run ;;
    *)         die "Unknown APP_MODE: $APP_MODE" ;;
  esac
}
