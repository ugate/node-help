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
$NVMRC_DIR/nvmrc.sh
NVMRC_STATUS=$?
if [[ ("$NVMRC_STATUS" != 0) ]]; then
  echo "$NVMRC_DIR/nvmrc.sh returned: $NVMRC_STATUS"
  exit $NVMRC_STATUS
fi
if [[ (-x "$NVM_DIR/nvm-exec") ]]; then
  echo "BUILD: using $NVM_DIR/nvm-exec"
else
  echo "BUILD: unable to find: $NVM_DIR/nvm-exec" >&2
  exit 1
fi

# enable nvm (alt "$NVM_DIR/nvm-exec node" or "$NVM_DIR/nvm-exec npm")
# source ~/.bashrc
# run node commands using app version in .nvmrc
#$NVM_DIR/nvm-exec node -v
#$NVM_DIR/nvm-exec npm -v
echo 'BUILD: node version:' && nvm node -v
echo 'BUILD: npm version:' && nvm npm -v
nvm $CMD_INSTALL
nvm $CMD_TEST
if [[ (-n "$CMD_BUNDLE") ]]; then
  nvm $CMD_BUNDLE
else
  echo "BUILD: No bundling performed"
fi
tar --exclude='./*git*' --exclude='./node_modules' --exclude='*.gz' -czvf $APP_NAME.tar.gz .
echo "BUILD: Success!"
