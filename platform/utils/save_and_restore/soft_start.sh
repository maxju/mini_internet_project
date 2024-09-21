#!/bin/bash
#
# Performs a soft start by restarting all group containers, DNS, MEASUREMENT, MATRIX, WEB, and PROXY

set -o errexit
set -o pipefail
set -o nounset

start_time=$(date +%s)

# start in the platform directory
DIRECTORY=$(pwd)
source "${DIRECTORY}"/config/subnet_config.sh

# read configs
readarray groups < "${DIRECTORY}"/config/AS_config.txt

group_numbers=${#groups[@]}

echo "$(date +%Y-%m-%d_%H-%M-%S)"
echo "Performing soft start..."

restart_container() {
    container_name="$1"
    echo "Restarting $container_name"
    docker restart "$container_name" &>/dev/null || echo "Failed to restart $container_name"
}

for ((k=0;k<group_numbers;k++)); do
    group_k=(${groups[$k]})
    group_number="${group_k[0]}"
    group_as="${group_k[1]}"
    group_config="${group_k[2]}"
    group_router_config="${group_k[3]}"
    group_layer2_switches="${group_k[5]}"
    group_layer2_hosts="${group_k[6]}"
    group_layer2_links="${group_k[7]}"

    if [ "${group_as}" != "IXP" ]; then
        readarray routers < "${DIRECTORY}"/config/$group_router_config
        readarray l2_switches < "${DIRECTORY}"/config/$group_layer2_switches
        readarray l2_hosts < "${DIRECTORY}"/config/$group_layer2_hosts
        n_routers=${#routers[@]}
        n_l2_switches=${#l2_switches[@]}
        n_l2_hosts=${#l2_hosts[@]}

        # Restart ssh container
        restart_container "${group_number}_ssh"

        for ((i=0;i<n_routers;i++)); do
            router_i=(${routers[$i]})
            rname="${router_i[0]}"
            property2="${router_i[2]}"
            dname=$(echo $property2 | cut -s -d ':' -f 2)

            # Restart router
            restart_container "${group_number}_${rname}router"

            # Restart host if it exists
            if [[ ! -z "${dname}" ]]; then
                docker ps -q --filter "name=^${group_number}_${rname}host" | xargs -r docker restart &>/dev/null || true
            fi

            # Restart layer 2 devices
            if [[ "${property2}" == *L2* ]]; then
                # Restart switches
                for ((l=0;l<n_l2_switches;l++)); do
                    switch_l=(${l2_switches[$l]})
                    l2name="${switch_l[0]}"
                    sname="${switch_l[1]}"
                    restart_container "${group_number}_L2_${l2name}_${sname}"
                done

                # Restart hosts
                for ((l=0;l<n_l2_hosts;l++)); do
                    host_l=(${l2_hosts[$l]})
                    hname="${host_l[0]}"
                    l2name="${host_l[2]}"
                    restart_container "${group_number}_L2_${l2name}_${hname}"
                done
            fi
        done
    elif [ "${group_as}" = "IXP" ]; then
        # Restart IXP router
        restart_container "${group_number}_IXP"
    fi
done

# Restart other containers
restart_container "DNS"
restart_container "MEASUREMENT"
restart_container "MATRIX"
restart_container "WEB"
restart_container "PROXY"

wait # wait for all background processes to finish

end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

echo "$(date +%Y-%m-%d_%H-%M-%S)"
echo "Soft start completed. All containers have been restarted."
echo "Time elapsed: $(printf '%02d:%02d:%02d' $((elapsed_time/3600)) $((elapsed_time%3600/60)) $((elapsed_time%60)))"
