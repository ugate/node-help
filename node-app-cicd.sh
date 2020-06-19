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
# $3 Node.js app dir (defaults to $PWD)
# $4 nvmrc.sh directory (defaults to "/opt")
# $5 npm/node ci/install command (defaults to "npm ci")
# $6 npm/node test command (defaults to "npm test", optional)
# $7 npm/node bundle/debundle command (defaults to "", optional)
# $8 Temporary directory for deployment backup and other temp files (defaults to "/tmp", DEPLOY only)

EXEC_TYPE=`[[ ("$1" == "BUILD" || "$1" == "DEPLOY") ]] && echo $1 || echo ""`
APP_NAME=`[[ (-n "$2") ]] && echo $2`
APP_DIR=`[[ (-n "$3") ]] && echo $3 || echo $PWD`
NVMRC_DIR=`[[ (-n "$4") ]] && echo $4 || echo "/opt"`
CMD_INSTALL=`[[ (-n "$5") ]] && echo $5 || echo "npm ci"`
CMD_TEST=`[[ (-n "$6") ]] && echo $6 || echo "npm test"`
CMD_BUNDLE=`[[ (-n "$7") ]] && echo $7 || echo ""`
APP_TMP=`[[ (-n "$8") ]] && echo $8 || echo /tmp`

if [[ (-n "$EXEC_TYPE") ]]; then
  echo "$EXEC_TYPE: starting..."
else
  echo "Missing or invalid execution type (first argument, either \"BUILD\" or \"DEPLOY\"" >&2
  exit 1
fi
if [[ (-n "$APP_NAME") ]]; then
  echo "$EXEC_TYPE: using app name $APP_NAME"
else
  echo "$EXEC_TYPE: missing app name argument" >&2
  exit 1
fi
if [[ (-d "$APP_DIR") ]]; then
  echo "$EXEC_TYPE: using app dir $APP_DIR"
  cd $APP_DIR
else
  echo "$EXEC_TYPE: unable to find dir $APP_DIR" >&2
  exit 1
fi
if [[ (-x "$NVMRC_DIR/nvmrc.sh") ]]; then
  echo "$EXEC_TYPE: using $NVMRC_DIR/nvmrc.sh"
else
  echo "$EXEC_TYPE: unable to find: $NVMRC_DIR/nvmrc.sh" >&2
  exit 1
fi

# ensure desired node version is installed using .nvmrc in base dir of app
# source nvmrc.sh so we have access to $NVMRC_VER
. $NVMRC_DIR/nvmrc.sh $PWD
CMD_STATUS=$?
if [[ ("$CMD_STATUS" != 0) ]]; then
  echo "$EXEC_TYPE: $NVMRC_DIR/nvmrc.sh returned: $CMD_STATUS" >&2
  exit $CMD_STATUS
elif [[ (-z "$NVMRC_VER") ]]; then
  echo "$EXEC_TYPE: $NVMRC_DIR/nvmrc.sh failed to set \$NVMRC_VER" >&2
  exit 1
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

# DEPLOY: handle archive extraction
if [[ ("$EXEC_TYPE" == "DEPLOY") ]]; then
  # Backup existing app deployment
  if [ -d "$APP_DIR" ]; then
    echo "$EXEC_TYPE: Backing up $APP_DIR ..."
    tar -czvf $APP_TMP/$APP_NAME-backup-`date +%Y%m%d_%H%M%S`.tar.gz $APP_DIR/*
    rm -rf $APP_DIR/*
  else
    mkdir -p $APP_DIR
    sudo chmod a+r $APP_DIR
  fi
  # Extract app
  tar --warning=no-timestamp -xzvf $APP_TMP/$APP_NAME.tar.gz -C $APP_DIR
  # Remove app archive
  rm -f $APP_TMP/$APP_NAME.tar.gz
fi

# change to app dir to execute node/npm commands
cd $APP_DIR

# execute install
echo "$EXEC_TYPE: \"$CMD_INSTALL\""
$CMD_INSTALL

# execute tests
if [[ (-n "$CMD_TEST") ]]; then
  echo "$EXEC_TYPE: \"$CMD_TEST\""
  $CMD_TEST
  CMD_STATUS=$?
  if [[ ("$CMD_STATUS" != 0) ]]; then
    echo "$EXEC_TYPE: \"$CMD_TEST\" returned: $CMD_STATUS" >&2
    exit $CMD_STATUS
  fi
else
  echo "$EXEC_TYPE: No tests being performed"
fi

# execute bundle/debundle
if [[ (-n "$CMD_BUNDLE") ]]; then
  echo "$EXEC_TYPE: \"$CMD_BUNDLE\""
  $CMD_BUNDLE
  CMD_STATUS=$?
  if [[ ("$CMD_STATUS" != 0) ]]; then
    echo "$EXEC_TYPE: \"$CMD_BUNDLE\" returned: $CMD_STATUS" >&2
    exit $CMD_STATUS
  fi
else
  echo "$EXEC_TYPE: No bundling/debundling being performed"
fi

# BUILD: create app archive
if [[ ("$EXEC_TYPE" == "BUILD") ]]; then
  tar --exclude='./*git*' --exclude='./node_modules' --exclude='*.gz' -czvf $APP_NAME.tar.gz .
fi

echo "$EXEC_TYPE: Success!"