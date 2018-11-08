#!/usr/bin/env bash

set -x -o errexit -o pipefail # Exit on error

# Constants
HEADER_API_KEY_NAME=X-Tddium-Api-Key
HEADER_CLIENT_NAME=X-Tddium-Client-Version
HEADER_CLIENT_VALUE=tddium-client_0.4.4
SOLANO_API_URL=https://ci.predix-ci-staging.gecis.io/1

source scripts/functions.sh

# Set the timestamp for building/testing the canary page
export ARTIFACT_DIR=`mktemp -d -t canary-artifacts.XXXXXXX`
mkdir -p $ARTIFACT_DIR
TIMESTAMP=`date +%s` # Use a consistent value of time 

# Ensure jq is installed
if ! which jq > /dev/null 2>&1; then
  install_jq
fi

# Determine $REPO_ID, $REPO_NAME, $BRANCH_ID, and $BRANCH_NAME for current session using API
# http://solano-api-docs.nfshost.com/
rm -f ${ARTIFACT_DIR}/repo_info.html.txt
if ! require_vars SOLANO_API_KEY; then
  echo "ERROR: \$SOLANO_API_KEY needs to be set" | tee -a $ARTIFACT_DIR/errors.txt
elif ! fetch_current_session_info; then
  echo "ERROR: Could not fetch current session information" | tee -a $ARTIFACT_DIR/errors.txt
fi

# Only searxh for previous results if we could lookup current session info above
if [ -f ${ARTIFACT_DIR}/repo_info.html.txt ]; then
  rm -f ${ARTIFACT_DIR}/previous_sessions.html.txt
  if ! fetch_previous_sessions_info; then
    echo "ERROR: Could not fetch previous session information" | tee -a $ARTIFACT_DIR/errors.txt
  fi
fi

# Build the canary page
./scripts/build_canary_webpage.sh $TIMESTAMP $ARTIFACT_DIR

# Ensure the canary page has the correct values
./scripts/test_canary_webpage.sh $TIMESTAMP
