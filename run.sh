#!/bin/sh
set -e
export SPM_LOG_LEVEL=${SPM_LOG_LEVEL:-error}
export SPM_LOG_TO_CONSOLE=${SPM_LOG_TO_CONSOLE:-true}
export SPM_COLLECTION_INTERVAL_IN_MS=${SPM_COLLECTION_INTERVAL_IN_MS:-30000}
export SPM_RECEIVER_URL=${SPM_URL:-$SPM_RECEIVER_URL}
export ENABLE_LOGSENE_STATS=${ENABLE_LOGSENE_STATS:-false}
export spmagent_spmSenderBulkInsertUrl=${SPM_RECEIVER_URL:-https://spm-receiver.sematext.com:443/receiver/v1/_bulk}
export DOCKER_PORT=${DOCKER_PORT:-2375}
export LOGSENE_TMP_DIR=/logsene-log-buffer
export MAX_CLIENT_SOCKETS=${MAX_CLIENT_SOCKETS:-1}
# clean docker inspect cache after 1 minute
export DOCKER_INSPECT_CACHE_EVICT_TIME=${DOCKER_INSPECT_CACHE_EVICT_TIME:-60000}

# unset SPM_TOKEN for swarm3k, all info should go only to LOGSENE
unset SPM_TOKEN
# avoid hitting SPM receivers during swarm3k test
export spmagent_spmSenderBulkInsertUrl=http://invalid-valid-host
# default is /tmp/ but this consumes 70 MB RAM
# to speed up GeoIP lookups the directory could be set back to /tmp/
export MAXMIND_DB_DIR=${MAXMIND_DB_DIR:-/usr/src/app/}
export SPM_COLLECTION_INTERVAL_IN_MS=${SPM_COLLECTION_INTERVAL_IN_MS:-10000}
export SPM_TRANSMIT_INTERVAL_IN_MS=${SPM_TRANSMIT_INTERVAL_IN_MS:-10000}

if [ -n "${PATTERNS_URL}" ]; then
  echo downloading logagent patterns: ${PATTERNS_URL}
  export LOGAGENT_PATTERNS=$(curl -s ${PATTERNS_URL})
  # echo "$LOGAGENT_PATTERNS"
fi

if [ -n "${LOGAGENT_PATTERNS}" ]; then
  mkdir -p /etc/logagent
  echo "writing LOGAGENT_PATTERNS to /etc/logagent/patterns.yml"
  echo "$LOGAGENT_PATTERNS" > /etc/logagent/patterns.yml
fi

export GEOIP_ENABLED=${GEOIP_ENABLED:-"false"}
if [[ "$GEOIP_ENABLED" == "true" && -n "${LOGSENE_TOKEN}" ]]; then
  echo "GeoIP lookups: enabled" 
fi

mkdir -p $LOGSENE_TMP_DIR

if [ -z "${DOCKER_HOST}" ]; then
  if [ -r /var/run/docker.sock ]; then
    export DOCKER_HOST=unix:///var/run/docker.sock
  else
    export DOCKER_HOST=tcp://$(netstat -nr | grep '^0\.0\.0\.0' | awk '{print $2}'):$DOCKER_PORT
    echo "/var/run/docker.sock is not available set DOCKER_HOST=$DOCKER_HOST"
  fi
fi

export SPM_REPORTED_HOSTNAME=$(docker-info Name)
echo "Docker Hostname: ${SPM_REPORTED_HOSTNAME}"

if [ -n "${DOCKERCLOUD_NODE_HOSTNAME}" ]; then
  export SPM_REPORTED_HOSTNAME=$DOCKERCLOUD_NODE_HOSTNAME
  echo "Docker Cloud Node Hostname: ${SPM_REPORTED_HOSTNAME}"
fi

if [ -n "${HOSTNAME_LOOKUP_URL}" ]; then
  echo Hostname lookup: ${HOSTNAME_LOOKUP_URL}
  export SPM_REPORTED_HOSTNAME=$(curl -s $HOSTNAME_LOOKUP_URL)
  echo "Hostname lookup from ${HOSTNAME_LOOKUP_URL}: ${SPM_REPORTED_HOSTNAME}"
fi



echo $(env)
exec sematext-agent-docker ${SPM_TOKEN}
