#!/usr/bin/env bash
# Copyright 2020-2021 RnD Center "ELVEES", JSC

DOCKERFILE=${DOCKERFILE:-Dockerfile.centos8stream}
DOCKER_IMAGE_TAG=elvees:mcom03-sbl-${DOCKERFILE#Dockerfile.}-v1.0

DOCKER_NETWORK=none

set -exuo pipefail

THIS_FILE_DIR=$(dirname "$(readlink -f "$0")")
readonly THIS_FILE_DIR

# build Docker image with empty context
docker build - < "${THIS_FILE_DIR}/${DOCKERFILE}" --tag "${DOCKER_IMAGE_TAG}"

# Detect if TTY available: it's not available on Jenkins,
# but useful for user to be able to interrupt the build with Ctrl-C
if [ -t 1 ]; then
    USE_TTY=('--tty' '--interactive')
else
    USE_TTY=()
fi

CONTAINER_CMD="$*"

if [ "${THIS_FILE_DIR:0:${#HOME}}" != "${HOME}" ]; then
    echo "Error: workdir $THIS_FILE_DIR not in HOME $HOME, will cause Zuul errors if mounted"
    exit 1
fi

if [[ ${ENABLE_NETWORK:-} == 1 ]]; then
    DOCKER_NETWORK="bridge"
fi

# Notes:
#
# * Network is disabled by default in container: docker image and software release must
#   be self-contained for reproducible build. If some packages can't be built without
#   network, ENABLE_NETWORK environment variable should be nonempty.
#
# * The entirety of $HOME is mounted because Zuul uses directories outside of PWD
#
# * The user is created so that git@ssh uses the correct user to log into Gerrit
#   - and the credentials are taken from $HOME/.ssh, which is mounted in Docker

docker run --rm "$DOCKER_IMAGE_TAG" cat /etc/passwd > .etcpasswd
echo "$USER:x:$(id -u):$(id -g)::$HOME:/bin/bash" >> .etcpasswd

docker run --rm \
    "${USE_TTY[@]}" \
    -v "$HOME":"$HOME" \
    -v "$PWD"/.etcpasswd:/etc/passwd:ro \
    -v /opt/gcc-arm-10.3-2021.07-x86_64-aarch64-none-elf:/opt/gcc-arm-10.3-2021.07-x86_64-aarch64-none-elf:ro \
    -v /opt/toolchain-mipsel-elvees-elf32:/opt/toolchain-mipsel-elvees-elf32:ro \
    --workdir="$THIS_FILE_DIR" \
    -u "$(id -u)":"$(id -g)" \
    --network=$DOCKER_NETWORK \
    "$DOCKER_IMAGE_TAG" \
    /bin/bash -cuxe "$CONTAINER_CMD"
