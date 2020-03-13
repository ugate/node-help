#!/bin/bash
# Ensure node version in .nvmrc is installed (e.g. lts/iron or v20.0.0)
# $NVM_DIR should be already set before running (usually auto loaded from profile)
# $1 The Node.js base directory for the app
source ~/.bashrc
if [[ (-z "$1") || (! -d "$1") ]]
then
  echo "First argument $1 must be a valid Node.js app base dir"
  exit 1
else
  echo "Using \$NVM_DIR=$NVM_DIR for $1/.nvmrc"
fi
NVMRC_RC=`cat $1/.nvmrc 2>/dev/null | sed 's/lts\///'`
if [[ (-z "$NVMRC_RC") ]]
then
  echo "No Node.js version or LTS codename in $1/.nvmrc"
  exit 1
fi
echo "Found .nvmrc version: $NVMRC_RC (excluding any \"lts/\" prefix)"
NVMRC_VER=`echo $NVMRC_RC | sed -nre 's/^[^0-9]*(([0-9]+\.)*[0-9]+).*/v\1/p'`
NVMRC_LTS_NAME=`[[ (-z "$NVMRC_VER") ]] && echo $NVMRC_RC || echo ''`
NVMRC_LTS_VER=`[[ (-n "$NVMRC_LTS_VER") ]] && cat $NVM_DIR/alias/lts/$NVMRC_LTS_NAME 2>/dev/null || echo ''`
echo "Extracted .nvmrc version: `[[ (-n "$NVMRC_LTS_VER $NVMRC_VER") ]] && echo $NVMRC_LTS_VER || echo $NVMRC_LTS_NAME $NVMRC_VER`"
if [[ (-z "$NVMRC_VER") ]]
then
  NVMRC_LTS_LATEST=`nvm ls-remote --lts | sed -nre "s/^.*(v[0-9]+\.[0-9]+\.[0-9]).*Latest LTS.*$NVMRC_LTS_NAME.*/\1/pi"`
  if [[ (-n "$NVMRC_LTS_LATEST") && ("$NVMRC_LTS_VER" != "$NVMRC_LTS_LATEST") ]]
  then
    echo "Installing latest Node.js lts/$NVMRC_RC: $NVMRC_LTS_LATEST"
    nvm install $NVMRC_LTS_LATEST
  else if [[ (-z "$NVMRC_LTS_VER") ]]
  then
    echo "Installing Node.js lts/$NVMRC_RC"
    nvm install lts/$NVMRC_RC
  else
    echo "Found installed Node.js version: $NVMRC_LTS_VERSION (lts/$NVMRC_LTS_NAME)"
  fi
else if [[ (-n "$NVMRC_VER") ]]
then
  NVMRC_VER_FOUND=`find $NVM_DIR/versions/node -type d -name "$NVMRC_VER" 2>/dev/null | wc -l`
  if [[ ("$NVMRC_VER_FOUND" -ge 1) ]]
  then
    echo "Found installed Node.js version: $NVMRC_VER"
  else
    echo "Installing Node.js version: $NVMRC_VER"
    nvm install $NVMRC_VER
  fi
fi
