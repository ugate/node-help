#!/bin/bash
# Ensure node version in .nvmrc is installed (e.g. lts/iron or v20.0.0)
# $NVM_DIR should be already set before running (usually auto loaded from profile)
# $1 Node.js app base directory (defaults to $PWD)
APP_DIR=`[[ (-n "$1") ]] && echo $1 || echo $PWD`
APP_NAME=`[[ (-n "$2") ]] && echo $2`
APP_TMP=`[[ (-n "$3") ]] && echo $3 || echo /tmp`
if [[ (-n "$APP_DIR") ]]; then
  echo "Using app dir $APP_DIR"
else
  echo "A valid app dir must be passed as the first argument!"
  exit 1
fi
if [[ (-n "$APP_NAME") ]]; then
  echo "Using app name $APP_NAME"
else
  echo "A valid app name must be passed as the second argument!"
  exit 1
fi
APP_PATH=$APP_DIR/$APP_NAME
if [ -d "$APP_PATH" ]; then
  echo "Backing up $APP_PATH ..."
  tar -czvf $APP_TMP/$APP_NAME-backup-`date +%Y%m%d_%H%M%S`.tar.gz $APP_PATH/*
  rm -rf $APP_PATH/*
else
  mkdir -p $APP_PATH
  sudo chmod a+r $APP_PATH
fi
tar --warning=no-timestamp -xzvf $APP_TMP/$APP_NAME.tar.gz -C $APP_PATH
rm -f $APP_TMP/$APP_NAME.tar.gz
