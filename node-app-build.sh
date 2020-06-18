#!/bin/bash
# Builds, tests and bundles (optional) a Node.js app into a compressed archive file.
# Also, ensures that the proper Node.js version is used via nvm. So, ensure the
# desired node version/name is in the .nvmrc file and it is present under root of
# the app's dir. For example, .nvmrc could contain lts/iron or v20.0.0 and will be
# installed (if needed)/used.
# $NVM_DIR should be already set before running (usually auto loaded from profile)
##################################################################################
# $1 Node.js app name (required)
# $2 Node.js app dir (defaults to $PWD)
# $3 npm/node install command (defaults to "npm ci")
# $4 npm/node test command (defaults to "npm test")
# $5 npm/node bundle command (defaults to "")
# $6 nvmrc.sh directory (defaults to "/opt")

APP_NAME=`[[ (-n "$1") ]] && echo $1`
APP_DIR=`[[ (-n "$2") ]] && echo $2 || echo $PWD`
CMD_INSTALL=`[[ (-z "$3") ]] && echo $3 || echo "npm ci"`
CMD_TEST=`[[ (-z "$4") ]] && echo $4 || echo "npm test"`
CMD_BUNDLE=`[[ (-z "$5") ]] && echo $5 || echo ""`
NVMRC_DIR=`[[ (-z "$6") ]] && echo $6 || echo "/opt"`

if [[ (-n "$APP_NAME") ]]; then
  echo "BUILD: using app name $APP_NAME"
else
  echo "BUILD: missing app name argument" >&2
  exit 1
fi
if [[ (-d "$APP_DIR") ]]; then
  echo "BUILD: using app dir $APP_DIR"
  cd $APP_DIR
else
  echo "BUILD: unable to find dir $APP_DIR" >&2
  exit 1
fi
if [[ (-x "$NVMRC_DIR/nvmrc.sh") ]]; then
  echo "BUILD: using $NVMRC_DIR/nvmrc.sh"
else
  echo "BUILD: unable to find: $NVMRC_DIR/nvmrc.sh" >&2
  exit 1
fi

# ensure desired node version is installed using .nvmrc in base dir of app
# source nvmrc.sh so we have access to $NVMRC_VER
. $NVMRC_DIR/nvmrc.sh $PWD
NVMRC_STATUS=$?
if [[ ("$NVMRC_STATUS" != 0) ]]; then
  echo "BUILD: $NVMRC_DIR/nvmrc.sh returned: $NVMRC_STATUS" >&2
  exit $NVMRC_STATUS
elif [[ (-z "$NVMRC_VER") ]]; then
  echo "BUILD: $NVMRC_DIR/nvmrc.sh failed to set \$NVMRC_VER" >&2
  exit 1
fi

# enable nvm (alt "$NVM_DIR/nvm-exec node" or "$NVM_DIR/nvm-exec npm")
source ~/.bashrc
NVM_EDIR=`[[ (-n "$NVM_DIR") ]] && echo $NVM_DIR || echo "$HOME/.nvm"`
#if [[ (-x "$(command -v nvm)") ]]; then
if [[ (-x "$NVM_EDIR/nvm-exec") ]]; then
  echo "BUILD: executing $NVM_EDIR/nvm-exec commands"
else
  echo "BUILD: $NVM_EDIR/nvm-exec command is not accessible" >&2
  exit 1
fi
# run node commands using app version in .nvmrc
nvm use "$NVMRC_VER"
$CMD_INSTALL
$CMD_TEST
if [[ (-n "$CMD_BUNDLE") ]]; then
  $CMD_BUNDLE
else
  echo "BUILD: No bundling performed"
fi
tar --exclude='./*git*' --exclude='./node_modules' --exclude='*.gz' -czvf $APP_NAME.tar.gz .
echo "BUILD: Success!"
