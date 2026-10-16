# Makes the launcher clickable: an app-menu entry and (optionally) a desktop icon,
# both pointing at the generated standalone launcher.

desktop::install() {
  local icon entry
  launcher::generate
  icon=$(desktop::prepare_icon)
  entry=$(desktop::menu_entry_path)

  mkdir -p "$(dirname "$entry")"
  desktop::render "$icon" >"$entry"
  chmod +x "$entry"
  log::ok "Menu entry: $entry"

  if is_true "$APP_DESKTOP_SHORTCUT"; then
    local shortcut
    shortcut=$(desktop::shortcut_path)
    cp "$entry" "$shortcut"
    chmod +x "$shortcut"
    # GNOME refuses to launch untrusted desktop files; mark ours as trusted.
    gio set "$shortcut" metadata::trusted true 2>/dev/null || true
    log::ok "Desktop icon: $shortcut"
  fi

  update-desktop-database -q "$(dirname "$entry")" 2>/dev/null || true
}

desktop::uninstall() {
  local file
  for file in "$(desktop::menu_entry_path)" "$(desktop::shortcut_path)" "$(launcher::path)"; do
    [[ -f $file ]] || continue
    rm -f "$file"
    log::ok "Removed $file"
  done
  rm -f "$LIFTOFF_DATA_DIR/icons/$APP_SLUG".*
}

desktop::render() {
  cat <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$APP_NAME
Comment=Launch $APP_NAME
Exec="$(launcher::path)"
Icon=$1
Terminal=$APP_TERMINAL
Categories=Development;
EOF
}

# APP_ICON may be a URL, an image file, or a theme icon name ("utilities-terminal").
# URLs and files are copied into Liftoff's data folder so the icon survives
# the original being moved or deleted.
desktop::prepare_icon() {
  local icons_dir="$LIFTOFF_DATA_DIR/icons" target ext

  if is_url "$APP_ICON"; then
    ext=$(desktop::icon_extension "${APP_ICON%%\?*}")
    target="$icons_dir/$APP_SLUG.$ext"
    mkdir -p "$icons_dir"
    log::info "Downloading icon $APP_ICON"
    curl -fsSL "$APP_ICON" -o "$target" || die "Could not download icon: $APP_ICON"
  elif [[ -f $APP_ICON ]]; then
    ext=$(desktop::icon_extension "$APP_ICON")
    target="$icons_dir/$APP_SLUG.$ext"
    mkdir -p "$icons_dir"
    cp "$APP_ICON" "$target"
  elif [[ $APP_ICON == */* ]]; then
    die "Icon file not found: $APP_ICON"
  else
    target=$APP_ICON
  fi

  printf '%s' "$target"
}

desktop::icon_extension() {
  local ext=${1##*.}
  ext=${ext,,}
  [[ $ext =~ ^(png|jpg|jpeg|svg|xpm|ico|webp)$ ]] || ext=png
  printf '%s' "$ext"
}

desktop::menu_entry_path() {
  printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/applications/liftoff-$APP_SLUG.desktop"
}

desktop::shortcut_path() {
  local desktop_dir
  desktop_dir=$(xdg-user-dir DESKTOP 2>/dev/null || printf '%s' "$HOME/Desktop")
  printf '%s' "$desktop_dir/$APP_SLUG.desktop"
}
