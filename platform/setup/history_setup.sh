#!/bin/bash
#
# Start the containers that will take regular snapshots of all configs.

set -o errexit
set -o pipefail
set -o nounset

DIRECTORY=$(readlink -f $1)
source "${DIRECTORY}"/config/variables.sh

# Source directories.
DATADIR="${DIRECTORY}/groups"
HISTORYDIR="${DATADIR}/history"
mkdir -p "${HISTORYDIR}"
MATRIXDIR="${DATADIR}/matrix"


docker run -itd --net='none' --name="HISTORY" \
    -v "/var/run/docker.sock":/var/run/docker.sock \
    -v "${HISTORYDIR}":/home/history \
    -v "${MATRIXDIR}":/home/matrix \
    -e "OUTPUT_DIR=/home/history" \
    -e "MATRIX_DIR=/home/matrix" \
    -e "UPDATE_FREQUENCY=${HISTORY_UPDATE_FREQUENCY}" \
    -e "TIMEOUT=${HISTORY_TIMEOUT}" \
    -e "GIT_USER=${HISTORY_GIT_USER}" \
    -e "GIT_EMAIL=${HISTORY_GIT_EMAIL}" \
    -e "GIT_URL=${HISTORY_GIT_URL}" \
    -e "GIT_BRANCH=${HISTORY_GIT_BRANCH}" \
    "${DOCKERHUB_PREFIX}d_history" > /dev/null

if $HISTORY_PAUSE_AFTER_START; then
    docker pause HISTORY
fi