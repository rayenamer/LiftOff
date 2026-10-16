# Works out how to install and start a project from the files in its folder.
#
# Sets:
#   STACK        human-readable name of what was detected
#   INSTALL_CMD  command that installs dependencies ('' = nothing to install)
#   START_CMD    command that starts the app
#   DEPS_FILE    file whose changes mean "reinstall" (lockfile, requirements.txt…)
#   DEPS_DIR     folder that must exist for deps to count as installed
#
# APP_INSTALL_CMD and APP_START_CMD, when set, always win.

stack::detect() {
  local dir=$1
  STACK=custom INSTALL_CMD='' START_CMD='' DEPS_FILE='' DEPS_DIR=''

  if   [[ -f $dir/package.json ]];                                    then stack::node "$dir"
  elif [[ -f $dir/requirements.txt || -f $dir/pyproject.toml ]];      then stack::python "$dir"
  elif [[ -f $dir/pom.xml ]];                                         then stack::maven "$dir"
  elif [[ -f $dir/build.gradle || -f $dir/build.gradle.kts ]];        then stack::gradle "$dir"
  elif [[ -f $dir/go.mod ]];                                          then stack::go
  elif [[ -f $dir/Cargo.toml ]];                                      then stack::rust
  elif stack::compose_file "$dir" >/dev/null;                         then stack::compose "$dir"
  fi

  INSTALL_CMD=${APP_INSTALL_CMD:-$INSTALL_CMD}
  START_CMD=${APP_START_CMD:-$START_CMD}
}

stack::node() {
  local dir=$1 manager=npm
  DEPS_DIR=node_modules

  if   [[ -f $dir/pnpm-lock.yaml ]];                     then manager=pnpm DEPS_FILE=pnpm-lock.yaml
  elif [[ -f $dir/yarn.lock ]];                          then manager=yarn DEPS_FILE=yarn.lock
  elif [[ -f $dir/bun.lock ]];                           then manager=bun  DEPS_FILE=bun.lock
  elif [[ -f $dir/bun.lockb ]];                          then manager=bun  DEPS_FILE=bun.lockb
  elif [[ -f $dir/package-lock.json ]];                  then manager=npm  DEPS_FILE=package-lock.json
  else                                                        manager=npm  DEPS_FILE=package.json
  fi

  STACK="node ($manager)"
  INSTALL_CMD="$manager install"
  [[ $DEPS_FILE == package-lock.json ]] && INSTALL_CMD='npm ci'

  # Most apps define "start"; Vite-style apps often only define "dev".
  local script=start
  if ! stack::has_npm_script "$dir" start && stack::has_npm_script "$dir" dev; then
    script=dev
  fi
  START_CMD="$manager run $script"
}

stack::has_npm_script() {
  grep -Eq "\"$2\"[[:space:]]*:" "$1/package.json"
}

stack::python() {
  local dir=$1
  STACK=python DEPS_DIR=.venv

  if [[ -f $dir/requirements.txt ]]; then
    DEPS_FILE=requirements.txt
    INSTALL_CMD='python3 -m venv .venv && .venv/bin/pip install -q -r requirements.txt'
  else
    DEPS_FILE=pyproject.toml
    INSTALL_CMD='python3 -m venv .venv && .venv/bin/pip install -q -e .'
  fi

  if   [[ -f $dir/manage.py ]]; then START_CMD='.venv/bin/python manage.py runserver'
  elif [[ -f $dir/main.py ]];   then START_CMD='.venv/bin/python main.py'
  elif [[ -f $dir/app.py ]];    then START_CMD='.venv/bin/python app.py'
  fi
}

stack::maven() {
  local dir=$1 mvn=mvn
  [[ -x $dir/mvnw ]] && mvn=./mvnw
  STACK=maven
  grep -q spring-boot "$dir/pom.xml" && START_CMD="$mvn spring-boot:run"
}

stack::gradle() {
  local dir=$1 gradle=gradle
  [[ -x $dir/gradlew ]] && gradle=./gradlew
  STACK=gradle
  if grep -qs spring-boot "$dir"/build.gradle*; then
    START_CMD="$gradle bootRun"
  else
    START_CMD="$gradle run"
  fi
}

stack::go() {
  STACK=go DEPS_FILE=go.sum
  INSTALL_CMD='go mod download'
  START_CMD='go run .'
}

stack::rust() {
  STACK=rust DEPS_FILE=Cargo.lock
  INSTALL_CMD='cargo fetch'
  START_CMD='cargo run'
}

stack::compose() {
  STACK='docker compose'
  INSTALL_CMD='docker compose pull --ignore-buildable'
  START_CMD='docker compose up --build'
  DEPS_FILE=$(stack::compose_file "$1")
}

stack::compose_file() {
  local name
  for name in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
    [[ -f $1/$name ]] && { printf '%s' "$name"; return 0; }
  done
  return 1
}
