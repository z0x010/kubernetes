#!/bin/bash

# Copyright 2016 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is for master and node instance health monitoring, which is
# packed in kube-manifest tarball. It is executed through a systemd service
# in cluster/gce/gci/<master/node>.yaml. The env variables come from an env
# file provided by the systemd service.

set -o nounset
set -o pipefail

# We simply kill the process when there is a failure. Another systemd service will
# automatically restart the process.
function docker_monitoring {
  while [ 1 ]; do
    if ! timeout 10 docker ps > /dev/null; then
      echo "Docker daemon failed!"
      pkill docker
      # Wait for a while, as we don't want to kill it again before it is really up.
      sleep 30
    else
      sleep "${SLEEP_SECONDS}"
    fi
  done
}

function kubelet_monitoring {
  echo "waiting a minute for startup"
  sleep 60
  local -r max_seconds=10
  while [ 1 ]; do
    if ! curl --insecure -m "${max_seconds}" -f -s https://127.0.0.1:${KUBELET_PORT:-10250}/healthz > /dev/null; then
      echo "Kubelet is unhealthy!"
      curl --insecure https://127.0.0.1:${KUBELET_PORT:-10250}/healthz
      pkill kubelet
      # Wait for a while, as we don't want to kill it again before it is really up.
      sleep 60
    else
      sleep "${SLEEP_SECONDS}"
    fi
  done
}


############## Main Function ################
if [[ "$#" -ne 1 ]]; then
  echo "Usage: health-monitor.sh <docker/kubelet>"
  exit 1
fi

KUBE_ENV="/home/kubernetes/kube-env"
if [[ ! -e "${KUBE_ENV}" ]]; then
  echo "The ${KUBE_ENV} file does not exist!! Terminate health monitoring"
  exit 1
fi

SLEEP_SECONDS=10
component=$1
echo "Start kubernetes health monitoring for ${component}"
source "${KUBE_ENV}"
if [[ "${component}" == "docker" ]]; then
  docker_monitoring 
elif [[ "${component}" == "kubelet" ]]; then
  kubelet_monitoring
else
  echo "Health monitoring for component "${component}" is not supported!"
fi
