#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

#set -xe

function dump_pod_log() {
    pod_name=$1
    namespace=$2
    echo "-----------Pod: $pod_name---------"
    echo "#kubectl describe pod $pod_name -n $namespace"
    kubectl describe pod $pod_name -n $namespace
    echo "-----------------------------------"
    echo "#kubectl logs $pod_name -n $namespace"
    kubectl logs $pod_name -n $namespace --all-containers --prefix=true
    echo "-----------------------------------"
}

function dump_pods_status() {
    namespace=$1
    echo "-----DUMP POD STATUS in NS $namespace------"
    kubectl get pods -n $namespace -o wide
    echo "-----------------------------------"

    # Get all pods in the namespace and their statuses
    pods=$(kubectl get pods -n $namespace --no-headers)

    # Loop through each pod
    echo "$pods" | while read -r line; do
        pod_name=$(echo $line | awk '{print $1}')
        ready=$(echo $line | awk '{print $2}')
        status=$(echo $line | awk '{print $3}')

        # Extract the READY count
        ready_count=$(echo $ready | cut -d'/' -f1)
        required_count=$(echo $ready | cut -d'/' -f2)

        # Check if the pod is not in "Running" status or READY count is less than required
        if [[ "$status" != "Running" || "$ready_count" -lt "$required_count" ]]; then
            dump_pod_log $pod_name $namespace
        fi
    done
}

function dump_failed_pod_logs() {
    namespace=$1
    logfile=$2

    failed_test_suite=$(awk '/TEST SUITE:/{suite=$0} /Phase:/{if($2=="Failed"){print suite; exit}}' "$logfile")
    failed_svc_name=$(echo "$failed_test_suite" | sed 's/^[ \t]*//;s/^TEST SUITE:[ \t]*//;s/-testpod$//')

    if [[ -n $failed_svc_name ]]; then
        # Get the exact pod name
        pods=$(kubectl get pods -n $namespace | grep -v 'testpod' | grep $failed_svc_name | awk '{print $1}')
        for pod_name in $pods
        do
            dump_pod_log $pod_name $namespace
        done
    fi
}

function dump_all_pod_logs() {
    namespace=$1
    echo "-----DUMP POD STATUS AND LOG in NS $namespace-----"
    echo "------SUMMARY of POD STATUS in NS $namespace------"
    kubectl get pods -n $namespace -o wide
    echo "--------------------------------------------------"

    pods=$(kubectl get pods -n $namespace -o jsonpath='{.items[*].metadata.name}')
    for pod_name in $pods
    do
        dump_pod_log $pod_name $namespace
    done
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <function_name>"
    exit 1
fi

case "$1" in
    dump_pods_status)
        dump_pods_status $2
        ;;
    dump_failed_pod_logs)
        dump_failed_pod_logs $2 $3
        ;;
    dump_all_pod_logs)
        dump_all_pod_logs $2
        ;;
    *)
        echo "Unknown function: $1"
        ;;
esac
