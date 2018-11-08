function install_docker {
  uname -a
  lsb_release -cs
  dig download.docker.com
  curl https://download.docker.com

  # Prepare to install docker
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update -y
  # Install docker and immediately stop it
  sudo apt-get install -y docker-ce
}

function require_vars {
  return_code=0
  for var in $@; do
    if [ -z "${!var}" ]; then
     echo "ERROR: required variable '${var}' is not set"
     return_code=1
    fi
  done
  return $return_code
}

function install_kubectl {
  export PATH=$PATH:/usr/local/sbin/
  export PATH=$PATH:/usr/sbin/
  export PATH=$PATH:/sbin
  apt-get update && apt-get install -y apt-transport-https
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
  deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
  apt-get update
  apt-get install -y kubectl
}

function fetch_current_session_info {
  echo "ARTIFACT DIR: ${ARTIFACT_DIR}"

  # The presenece of these environment variables presumes this is a CI build
  if ! require_vars TDDIUM_SESSION_ID; then
    echo 'Not generated from CI build' | tee -a $ARTIFACT_DIR/errors.txt
    return 1
  fi
  if ! require_vars SOLANO_API_KEY HEADER_API_KEY_NAME HEADER_CLIENT_NAME HEADER_CLIENT_VALUE SOLANO_API_URL; then
    echo "Not all required environment variables are set to query api" | tee -a $ARTIFACT_DIR/errors.txt
    return 2
  fi
  # Store current session info for 'jq' parsing
  CURRENT_SESSION_FILE=${ARTIFACT_DIR}/current_session.json
  if ! curl -H "Content-type: application/json" -H "${HEADER_CLIENT_NAME}: ${HEADER_CLIENT_VALUE}" -H "${HEADER_API_KEY_NAME}: ${SOLANO_API_KEY}" \
    --silent --show-error -k \
    -o $CURRENT_SESSION_FILE \
    ${SOLANO_API_URL}/sessions/${TDDIUM_SESSION_ID} \
    2>${CURRENT_SESSION_FILE}-stderr.txt; then
      echo "ERROR: There was an error querying the API" | tee -a $ARTIFACT_DIR/errors.txt
      echo "       see $(basename ${CURRENT_SESSION_FILE}-stderr.txt)" | tee -a $ARTIFACT_DIR/errors.txt
      return 3
  fi
  # Extract info from json results
  BRANCH_ID=$(cat $CURRENT_SESSION_FILE | jq '.session.branch_id')
  BRANCH_NAME="$(cat $CURRENT_SESSION_FILE | jq -r '.session.branch_name')"  # Equivalent of $TDDIUM_CURRENT_BRANCH 
  REPO_ID=$(cat $CURRENT_SESSION_FILE | jq '.session.repo_id')
  REPO_NAME="$(cat $CURRENT_SESSION_FILE | jq -r '.session.repo_name')"
  if [[ -z "$BRANCH_ID" || "$BRANCH_ID" == "null" ]]; then
    echo "ERROR: Could not extract 'branch_id' for current session from API" | tee -a $ARTIFACT_DIR/errors.txt
    return 4
  fi
  if [[ -z "$BRANCH_NAME" || "$BRANCH_NAME" == "null" ]]; then
    echo "ERROR: Could not extract 'branch_name' for current session from API" | tee -a $ARTIFACT_DIR/errors.txt
    return 4
  fi
  if [[ -z "$REPO_ID" || "$REPO_ID" == "null" ]]; then
    echo "ERROR: Could not extract 'repo_id' for current session from API" | tee -a $ARTIFACT_DIR/errors.txt
    return 5
  fi
  if [[ -z "$REPO_NAME" || "$REPO_NAME" == "null" ]]; then
    echo "ERROR: ould not extract 'repo_id' for current session from API" | tee -a $ARTIFACT_DIR/errors.txt
    return 6
  fi
  echo "Repo: ${REPO_NAME} (${REPO_ID})" | tee -a $ARTIFACT_DIR/repo_info.html.txt
  echo "Branch: ${BRANCH_NAME} (${BRANCH_ID})" | tee -a $ARTIFACT_DIR/repo_info.html.txt
}

function fetch_previous_sessions_info {
  if ! require_vars BRANCH_ID; then
    echo "ERROR: The \$BRANCH_ID is required to query previous session status" | tee -a $ARTIFACT_DIR/errors.txt
    return 1
  fi
  if ! require_vars SOLANO_API_KEY HEADER_API_KEY_NAME HEADER_CLIENT_NAME HEADER_CLIENT_VALUE SOLANO_API_URL; then
    echo "ERROR: Not all required environment variables are set to query api" | tee -a $ARTIFACT_DIR/errors.txt
    return 2
  fi
  # Store previous session info for 'jq' parsing
  PREVIOUS_SESSIONS_FILE=${ARTIFACT_DIR}/previous_sessions.json
  if ! curl -H "Content-type: application/json" -H "${HEADER_CLIENT_NAME}: ${HEADER_CLIENT_VALUE}" -H "${HEADER_API_KEY_NAME}: ${SOLANO_API_KEY}" \
    --silent --show-error -k \
    -o $PREVIOUS_SESSIONS_FILE \
    ${SOLANO_API_URL}/sessions?suite_id={$BRANCH_ID}\&limit=5 \
    2>${PREVIOUS_SESSIONS_FILE}-stderr.txt; then
      echo "ERROR: There was an error querying the API" | tee -a $ARTIFACT_DIR/errors.txt
      echo "       see $(basename ${PREVIOUS_SESSIONS_FILE}-stderr.txt)" | tee -a $ARTIFACT_DIR/errors.txt
      return 3
  fi
  # For each session, add an html line
  cat $PREVIOUS_SESSIONS_FILE | jq -c '.sessions[]' | while read line; do
    ID=$(echo $line | jq '.id')
    URL=$(echo $line | jq -r '.report')
    STATUS=$(echo $line | jq -r '.status')
    echo "<a title='Session ${ID}' href='${URL}' class='${STATUS}'>${ID} - ${STATUS}</a>" | tee -a $ARTIFACT_DIR/previous_sessions.html.txt
  done
}

function install_jq {
  mkdir -p $HOME/bin
  wget -O $HOME/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
  chmod +x $HOME/bin/jq
}
