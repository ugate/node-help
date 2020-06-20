#!/bin/bash
# Performs either a Node.js app BUILD or DEPLOY depending on the passed execution type.
# BUILD/DEPLOY: Ensures that the proper Node.js version is used via nvm. So, ensure the desired
# Noode.js version/name is in the .nvmrc file and it is present under root of the app's dir. For
# example, .nvmrc could contain lts/iron or v20.0.0 and will be installed (if needed)/used.
# $NVM_DIR should be already set before running (usually auto loaded from profile).
# BUILD: Builds, tests and bundles (optional) a Node.js app into a compressed archive file.
# DEPLOY: Backs up the existing Node.js app (if present), extracts the archive created from
# the build and tests the app (optional).
##################################################################################
# $1 Execution type (either BUILD or DEPLOY)
# $2 Node.js app name (required)
# $3 Node.js app dir (defaults to "")
# $4 nvmrc.sh directory (defaults to "/opt")
# $5 npm/node ci/install command (defaults to "npm ci")
# $6 npm/node test command (defaults to "npm test", optional)
# $7 npm/node bundle/debundle command (defaults to "", optional)
# $8 node environment that will be used to set NODE_ENV (defaults to "test", DEPLOY only)
# $9 node app starting port for service (increments int to number of physical cores, DEPLOY only)
# $10 Temporary directory for deployment backup and other temp files (defaults to "/tmp", DEPLOY only)

EXEC_TYPE=`[[ ("$1" == "BUILD" || "$1" == "DEPLOY") ]] && echo $1 || echo ""`
APP_NAME=`[[ (-n "$2") ]] && echo $2`
APP_DIR=`[[ (-n "$3") ]] && echo $3 || echo ""`
NVMRC_DIR=`[[ (-n "$4") ]] && echo $4 || echo "/opt"`
CMD_INSTALL=`[[ (-n "$5") ]] && echo $5 || echo "npm ci"`
CMD_TEST=`[[ (-n "$6") ]] && echo $6 || echo "npm test"`
CMD_BUNDLE=`[[ (-n "$7") ]] && echo $7 || echo ""`
APP_PORT_START=`[[ "$8" =~ ^[0-9]+$ ]] && echo $8 || echo ""`
NODE_ENV=`[[ (-n "$9") ]] && echo $9 || echo "test"`
APP_TMP=`[[ (-n "${10}") ]] && echo ${10} || echo /tmp`

execCmdCICD () {
  if [[ (-n "$1") ]]; then
    echo "$EXEC_TYPE: \"$1\""
    $1
    local CMD_STATUS=$?
    if [[ ("$CMD_STATUS" != 0) ]]; then
      echo "$EXEC_TYPE: $2 \"$1\" returned: $CMD_STATUS" >&2
      return $CMD_STATUS
    fi
  else
    echo "$EXEC_TYPE: No $2 being performed"
  fi
}

if [[ (-n "$EXEC_TYPE") ]]; then
  echo "$EXEC_TYPE: starting..."
else
  echo "Missing or invalid execution type (first argument, either \"BUILD\" or \"DEPLOY\"" >&2
  exit 1
fi
if [[ "$APP_NAME" =~ [^a-zA-Z] ]]; then
  echo "$EXEC_TYPE: missing or invalid app name \"$APP_NAME\" (must contain only alpha characters)" >&2
  exit 1
else
  echo "$EXEC_TYPE: using app name $APP_NAME"
fi
if [[ (-d "$APP_DIR") ]]; then
  echo "$EXEC_TYPE: using app dir $APP_DIR"
  if [[ ("$EXEC_TYPE" == "DEPLOY") ]]; then
    echo "$EXEC_TYPE: backing up $APP_DIR ..."
    tar -czf $APP_TMP/$APP_NAME-backup-`date +%Y%m%d_%H%M%S`.tar.gz $APP_DIR/*
    [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to backup $APP_DIR to $APP_TMP" >&2; exit 1; }
  fi
elif [[ ("$EXEC_TYPE" == "BUILD") ]]; then
  echo "$EXEC_TYPE: unable to find dir $APP_DIR" >&2
  exit 1
elif [[ (-z "$APP_DIR") ]]; then
  echo "$EXEC_TYPE: app dir is required" >&2
  exit 1
else
  # DEPLOY: create new app dir
  sudo mkdir -p $APP_DIR
fi
if [[ ("$EXEC_TYPE" == "DEPLOY") ]]; then
  # check if the service is installed
  if [[ -n "$APP_PORT" ]]; then
    TARGETED=`sudo systemctl list-units --all -t target --full --no-legend | grep "$APP_NAME.target"`
    if [[ -z "$TARGETED" ]]; then
      # match the number of processes/services with the number of physical cores
      CORE_CNT=`getconf _NPROCESSORS_ONLN`
      for (( c=$APP_PORT; c<=$CORE_CNT + $APP_PORT; c++ )); do
        echo "$EXEC_TYPE: checking if port $c is in use"
        PORT_USED=`sudo ss -tulwnH "( sport = :$c )"`
        if [[ -n "$PORT_USED" ]]; then
          echo "$EXEC_TYPE: app port $c is already in use (core count: $CORE_CNT, start port: $APP_PORT)" >&2
          exit 1
        fi
        SERVICES=`[[ -n "$SERVICES" ]] && echo "$SERVICES " || echo ""`
        SERVICES="$SERVICES$APP_NAME@$c.service"
      done
    else
      sudo systemctl stop $APP_NAME.target
      [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to stop $APP_NAME.target" >&2; exit 1; }
    fi
  fi
  sudo chown -hR $USER $APP_DIR
  # replace app contents with extracted content
  if [[ (-f "$APP_TMP/$APP_NAME.tar.gz") ]]; then
    echo "$EXEC_TYPE: cleaning app at $APP_DIR"
    sudo rm -rfd $APP_DIR/*
    [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to clean $APP_DIR" >&2; exit 1; }
    echo "$EXEC_TYPE: extracting app contents from $APP_TMP/$APP_NAME.tar.gz to $APP_DIR"
    tar --warning=no-timestamp --strip-components=1 -xzvf $APP_TMP/$APP_NAME.tar.gz -C $APP_DIR
    [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to extract $APP_TMP/$APP_NAME.tar.gz to $APP_DIR" >&2; exit 1; }
    # remove extracted app archive
    sudo rm -f $APP_TMP/$APP_NAME.tar.gz
  else
    echo "$EXEC_TYPE: missing archive at $APP_TMP/$APP_NAME.tar.gz" >&2
    exit 1
  fi
fi
# change to app dir to execute node/npm commands
cd $APP_DIR

# ensure desired node version is installed using .nvmrc in base dir of app
if [[ (-x "$NVMRC_DIR/nvmrc.sh") ]]; then
  echo "$EXEC_TYPE: using nvmrc.sh located at \"$NVMRC_DIR/nvmrc.sh\""
else
  echo "$EXEC_TYPE: unable to find: \"$NVMRC_DIR/nvmrc.sh\"" >&2
  exit 1
fi
# source nvmrc.sh so we have access to $NVMRC_VER that is exported by nvmrc.sh
. $NVMRC_DIR/nvmrc.sh $PWD
CMD_STATUS=$?
if [[ ("$CMD_STATUS" != 0) ]]; then
  echo "$EXEC_TYPE: $NVMRC_DIR/nvmrc.sh returned: $CMD_STATUS" >&2
  exit $CMD_STATUS
elif [[ (-z "$NVMRC_VER") ]]; then
  echo "$EXEC_TYPE: $NVMRC_DIR/nvmrc.sh failed to set \$NVMRC_VER" >&2
  exit 1
fi

# DEPLOY: service/target templates
# ExecStart=/bin/bash -c '$NVM_DIR/nvm_exec node .'
SERVICE=`[[ -z "$SERVICES" ]] && echo "" || echo "
# /etc/systemd/system/$APP_NAME@.service
[Unit]
Description=\"$APP_NAME (%H:%i)\"
After=network.target
# Wants=redis.service
PartOf=$APP_NAME.target

[Service]
Environment=NODE_ENV=$NODE_ENV
Environment=NODE_HOST=%H
Environment=NODE_PORT=%i
Type=simple
# user should match the user where nvm was installed
User=$USER
WorkingDirectory=$APP_DIR
# run node using the node version defined in working dir .nvmrc
ExecStart=/bin/bash -c '~/.nvm/nvm_exec node .'
Restart=on-failure
RestartSec=5
StandardError=syslog

[Install]
WantedBy=multi-user.target
"`
TARGET=`[[ -z "$SERVICES" ]] && echo "" || echo "
# /etc/systemd/system/$APP_NAME.target
[Unit]
Description=\"$APP_NAME\"
Wants=$SERVICES

[Install]
WantedBy=multi-user.target
"`

if [[ -n "$SERVICE" && -n "$TARGET" ]]; then
  SERVICE_PATH=`/etc/systemd/system/$APP_NAME@.service`
  TARGET_PATH=`/etc/systemd/system/$APP_NAME.target`
  sudo echo "$EXEC_TYPE: creating $SERVICE_PATH and $TARGET_PATH"
  sudo echo "$SERVICE" > "$SERVICE_PATH"
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to write $SERVICE_PATH" >&2; exit 1; }
  sudo echo "$TARGET" > "$TARGET_PATH"
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to write $TARGET_PATH" >&2; exit 1; }
  sudo systemctl daemon-reload
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to reload the service/target daemon" >&2; exit 1; }
  sudo systemctl enable $APP_NAME.target
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to enable $TARGET_PATH" >&2; exit 1; }
fi

# enable nvm (alt "$NVM_DIR/nvm-exec node" or "$NVM_DIR/nvm-exec npm")
#NVM_EDIR=`[[ (-n "$NVM_DIR") ]] && echo $NVM_DIR || echo "$HOME/.nvm"`
#if [[ (-x "$NVM_EDIR/nvm-exec") ]]; then
source ~/.bashrc
if [[ ("$(command -v nvm)" == "nvm") ]]; then
  echo "$EXEC_TYPE: executing nvm commands"
else
  echo "$EXEC_TYPE: nvm command is not accessible for execution" >&2
  exit 1
fi

# run node commands using app version in .nvmrc
nvm use "$NVMRC_VER"

if [[ ("$EXEC_TYPE" == "BUILD") ]]; then
  # execute install
  execCmdCICD "$CMD_INSTALL" "ci/install"
  [[ $? != 0 ]] && exit 1
  # execute tests
  execCmdCICD "$CMD_TEST" "tests"
  [[ $? != 0 ]] && exit 1
  # execute bundle
  execCmdCICD "$CMD_BUNDLE" "bundling"
  [[ $? != 0 ]] && exit 1
  # create app archive
  tar --exclude='./*git*' --exclude='./node_modules' --exclude='*.gz' -czvf $APP_NAME.tar.gz .
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to create app archive $APP_NAME.tar.gz" >&2; exit 1; }
else
  # execute debundle
  execCmdCICD "$CMD_BUNDLE" "debundling"
  [[ $? != 0 ]] && exit 1
  # execute install
  execCmdCICD "$CMD_INSTALL" "ci/install"
  [[ $? != 0 ]] && exit 1
  # start the services
  sudo systemctl start $APP_NAME.target
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to start $APP_NAME.target" >&2; exit 1; }
  SERVICE_STARTED=`sudo systemctl is-active "$APP_NAME" >/dev/null 2>&1 && echo ACTIVE || echo ""`
  [[ -z "$SERVICE_STARTED" ]] && { echo "$EXEC_TYPE: $APP_NAME.target is not active" >&2; exit 1; }
  # execute tests
  execCmdCICD "$CMD_TEST" "tests"
  [[ $? != 0 ]] && exit 1
fi

echo "$EXEC_TYPE: Success!"