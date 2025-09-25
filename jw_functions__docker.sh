# shellcheck shell=bash


# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------

jwdocker_toc() {
    echo
    echo " -----------------------------  legacy: aliases"
    echo " - jwdlf"
    echo " - jwdockerfindcontainerbyip"
    echo " - jwdockerps"
    echo
    echo " -----------------------------  legacy: inspectors"
    echo " - jwdockerinspectcontainer"
    echo " - jwdockerinspectnetwork"
    echo
    echo " -----------------------------  ps"
    echo " - jwdocker_psup"
    echo " - jwdocker_psall"
    echo " - jwdocker_psdown"
    echo
    echo " -----------------------------  container lifecycle management"
    echo " - jwdocker_containers"
    echo " - jwdocker_container-start"
    echo " - jwdocker_container-stop"
    echo " - jwdocker_container-restart"
    echo " - jwdocker_container-remove"
    echo
    echo " -----------------------------  image management"
    echo " - jwdocker_images"
    echo " - jwdocker_image-pull"
    echo " - jwdocker_image-build"
    echo " - jwdocker_image-rm"
    echo " - jwdocker_image-history"
    echo
    echo " -----------------------------  volume management"
    echo " - jwdocker_volumes"
    echo " - jwdocker_volume-inspect"
    echo " - jwdocker_volume-create"
    echo " - jwdocker_volume-remove"
    echo " - jwdocker_volume-prune"
    echo
    echo " -----------------------------  network management"
    echo " - jwdocker_networks"
    echo " - jwdocker_network-create"
    echo " - jwdocker_network-remove"
    echo " - jwdocker_network-connect"
    echo " - jwdocker_network-disconnect"
    echo " - jwdocker_network-prune"
    echo
    echo " -----------------------------  resource monitoring"
    echo " - jwdocker_monitor-stats"
    echo " - jwdocker_monitor-top"
    echo " - jwdocker_monitor-health"
    echo
    echo " -----------------------------  system cleanup & maintenance"
    echo " - jwdocker_disk-usage"
    echo " - jwdocker_system-info"
    echo " - jwdocker_prune"
    echo " - jwdocker_cleanup"
    echo " - jwdocker_size"
    echo
    echo " -----------------------------  import/export utilities"
    echo " - jwdocker_save"
    echo " - jwdocker_load"
    echo " - jwdocker_export"
    echo " - jwdocker_import"
    echo
    echo " -----------------------------  quick utility functions"
    echo " - jwdocker_search"
    echo " - jwdocker_backup"
    echo " - jwdocker_cp"
    echo " - jwdocker_run"
    echo " - jwdocker_tag"
    echo " - jwdocker_push"
    echo " - jwdocker_connectivity"
    echo
    echo " -----------------------------  troubleshooting tools"
    echo " - jwdocker_exec"
    echo " - jwdocker_logs"
    echo " - jwdocker_port"
    echo
}


# ---------------------------------------------------------------------------------
# legacy: aliases
# ---------------------------------------------------------------------------------

alias jwdlf="docker logs -f"
alias jwdockerfindcontainerbyip="docker ps -q | xargs -n 1 docker inspect -f '{{.Id}} {{.Name}}  -  {{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' | grep"
alias jwdockerps="jwdocker_containers"


# ---------------------------------------------------------------------------------
# legacy: inspectors
# ---------------------------------------------------------------------------------

jwdockerinspectcontainer() {
    # [https://docs.docker.com/config/formatting/]
    # [https://golang.org/pkg/text/template/#hdr-Functions]
    # [https://golang.org/pkg/fmt/]
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker ps --filter status=running --format "- {{.Names}}"
        echo "---"
        docker ps --filter status=created \
                  --filter status=restarting \
                  --filter status=removing \
                  --filter status=paused \
                  --filter status=exited \
                  --filter status=dead --format "- {{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    echo
    echo "---[ Container ]---------------------------------------"
    docker inspect -f 'Id:            {{ .Id }}' "$CONTAINER"
    docker inspect -f 'Hostname:      {{ .Config.Hostname }} ({{ .Name }})' "$CONTAINER"
    docker inspect -f 'Image:         {{ .Config.Image }}' "$CONTAINER"
    docker inspect -f 'Path:          {{ .Path }}' "$CONTAINER"
    docker inspect -f 'Command:       {{json .Config.Cmd }}' "$CONTAINER"
    docker inspect -f 'Entrypoint:    {{json .Config.Entrypoint }}' "$CONTAINER"
    docker inspect -f 'User:          {{ .Config.User }}' "$CONTAINER"
    docker inspect -f 'WorkDir:       {{ .Config.WorkingDir }}' "$CONTAINER"
    docker inspect -f 'ExtraHosts:    {{json .HostConfig.ExtraHosts }}' "$CONTAINER"
    docker inspect -f 'RestartCount:  {{ .RestartCount }}' "$CONTAINER"
    echo
    echo "---[ Ports ]-------------------------------------------"
    docker inspect -f '{{ range $key, $value := .NetworkSettings.Ports }}{{printf "%s -> %s\n" $value $key}}{{ end }}' "$CONTAINER"
    echo "---[ Volumes ]-----------------------------------------"
    docker inspect -f '{{ range $item := .Mounts }}{{printf "\"%s\" [%s]  ->  %s : %s\n" .Type .Mode .Source .Destination}}{{ end }}' "$CONTAINER"
    echo "---[ Networks ]----------------------------------------"
    docker inspect -f '{{ range $key, $value := .NetworkSettings.Networks }}{{printf "\"%s\"  [NetworkID: %s]  -->  IP: %s , Aliases: %s\n" $key .NetworkID .IPAddress .Aliases}}{{ end }}' "$CONTAINER"
    echo "---[ RestartPolicy ]-----------------------------------"
    docker inspect -f '{{ range $key, $value := .HostConfig.RestartPolicy }}{{ printf "  %-22s" $key }}{{ $value }}{{ printf "\n" }}{{ end }}' "$CONTAINER"
    echo "---[ Labels ]------------------------------------------"
    docker inspect -f '{{ range $key, $value := .Config.Labels }}{{ printf "  %-40s" $key }}{{ $value }}{{ printf "\n" }}{{ end }}' "$CONTAINER"
    echo "---[ Env ]---------------------------------------------"
    docker inspect -f '{{ range $item := .Config.Env }}{{ range $ii := split $item "=" }}{{printf "  %-30s" $ii}}{{ end }}{{"\n"}}{{ end }}' "$CONTAINER" | grep -v "^$" | sort ; echo
    echo "---[ State ($(docker inspect  -f '{{ .State.Status }}' "$CONTAINER")) ]---------------------------------"
    docker inspect -f '{{ range $key, $value := .State }}{{ printf "  %-15s" $key }}{{ $value }}{{ printf "\n" }}{{ end }}' "$CONTAINER"
}


jwdockerinspectnetwork() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker network ls | awk '{print $2}' | tail -n +2
        echo
        return 1
    fi

    local NETWORK=$1
    echo
    echo "-------------- Network:"
    docker inspect -f 'Id:         {{ .Id }}  [{{ .Name }}]' "$NETWORK"
    docker inspect -f 'Scope:      {{ .Scope }}' "$NETWORK"
    docker inspect -f 'Driver:     {{ .Driver }}' "$NETWORK"
    docker inspect -f '{{ range $item := .IPAM.Config }}{{ range $key, $value := $item }}{{printf "%s\t\t%s\n" $key $value}}{{ end }}{{ end }}' "$NETWORK"
    echo "-------------- Containers:"
    docker network inspect -f '{{ range $key, $value := .Containers }}{{printf "%s: [%s]  %s\n" $key .IPv4Address .Name}}{{ end }}' "$NETWORK"
}


# ---------------------------------------------------------------------------------
# ps 
# ---------------------------------------------------------------------------------

alias jwdocker_psup="jwdocker_containers"


jwdocker_psall() {
    if [ $# -eq 0 ]; then
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    else
        # Filter all containers by name
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | head -1
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -i "$1"
    fi
}


jwdocker_psdown() {
    if [ $# -eq 0 ]; then
        docker ps --filter status=created \
                  --filter status=restarting \
                  --filter status=removing \
                  --filter status=paused \
                  --filter status=exited \
                  --filter status=dead --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    else
        # Filter stopped containers by name
        docker ps --filter status=created \
                  --filter status=restarting \
                  --filter status=removing \
                  --filter status=paused \
                  --filter status=exited \
                  --filter status=dead --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | head -1
        docker ps --filter status=created \
                  --filter status=restarting \
                  --filter status=removing \
                  --filter status=paused \
                  --filter status=exited \
                  --filter status=dead --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -i "$1"
    fi
}


# ---------------------------------------------------------------------------------
# container lifecycle management
# ---------------------------------------------------------------------------------

jwdocker_containers() {
    if [ $# -eq 0 ]; then
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    else
        # Filter running containers by name
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | head -1
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -i "$1"
    fi
}


jwdocker_container-start() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker ps --filter status=exited --filter status=created --format "{{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    echo "Starting container: $CONTAINER"
    docker start "$CONTAINER"
    
    # Show status after starting
    sleep 1
    docker ps --filter name="^${CONTAINER}$" --format "table {{.Names}}\t{{.Status}}"
}


jwdocker_container-stop() {
    if [ $# -eq 0 ]; then
        local running_containers
        running_containers=$(docker ps --filter status=running --format "{{.Names}}")
        
        if [ -z "$running_containers" ]; then
            echo "No running containers found."
            return 0
        fi
        
        echo "Currently running:"
        while IFS= read -r container; do
            echo " - $container"
        done <<< "$running_containers"
        echo -n "Stop all? [y/N] "
        read -r response
        
        if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            echo "Stopping all running containers..."
            echo "$running_containers" | while read -r container; do
                [ -n "$container" ] && docker stop --time=20 "$container"
            done
            echo "All containers stopped."
        else
            echo "Operation cancelled."
        fi
        return 0
    fi

    local CONTAINER=$1
    local TIMEOUT=${2:-20}
    
    echo "Stopping container: $CONTAINER (timeout: ${TIMEOUT}s)"
    docker stop --time="$TIMEOUT" "$CONTAINER"
    
    # Show status after stopping
    docker ps -a --filter name="^${CONTAINER}$" --format "table {{.Names}}\t{{.Status}}"
}


jwdocker_container-restart() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker ps -a --format "{{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    local TIMEOUT=${2:-20}
    
    echo "Restarting container: $CONTAINER (timeout: ${TIMEOUT}s)"
    docker restart --time="$TIMEOUT" "$CONTAINER"
    
    # Show status after restarting
    sleep 1
    docker ps --filter name="^${CONTAINER}$" --format "table {{.Names}}\t{{.Status}}"
}


jwdocker_container-remove() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker ps -a --filter status=exited --filter status=created --format "{{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    local FORCE=${2:-false}
    
    # Safety check - don't remove running containers without force flag
    if docker ps --filter name="^${CONTAINER}$" --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        if [ "$FORCE" != "force" ] && [ "$FORCE" != "-f" ]; then
            echo "Error: Container '$CONTAINER' is running. Stop it first or use 'force' flag."
            echo "Usage: jwdockerremove $CONTAINER force"
            return 1
        fi
        echo "Force removing running container: $CONTAINER"
        docker rm -f "$CONTAINER"
    else
        echo "Removing stopped container: $CONTAINER"
        docker rm "$CONTAINER"
    fi
}


# ---------------------------------------------------------------------------------
# image management
# ---------------------------------------------------------------------------------

jwdocker_images() {
    if [ $# -eq 0 ]; then
        # Show all images with clean formatting
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}"
    else
        # Filter images by repository name
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | head -1
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | grep -i "$1"
    fi
}


jwdocker_image-pull() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockerimagepull <image[:tag]>"
        echo "Examples:"
        echo "  jwdockerimagepull nginx"
        echo "  jwdockerimagepull nginx:alpine"
        echo "  jwdockerimagepull ubuntu:20.04"
        return 1
    fi

    local IMAGE=$1
    echo "Pulling image: $IMAGE"
    docker pull "$IMAGE"
    
    # Show the pulled image info
    echo
    echo "---[ Pulled Image Info ]---------------------------"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | head -1
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | grep "$(echo "$IMAGE" | cut -d: -f1)"
}


jwdocker_image-build() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockerimagebuild <tag> [dockerfile_path] [build_context]"
        echo "Examples:"
        echo "  jwdockerimagebuild myapp:latest"
        echo "  jwdockerimagebuild myapp:v1.0 ./Dockerfile ."
        echo "  jwdockerimagebuild myapp:dev ./docker/Dockerfile.dev ./src"
        return 1
    fi

    local TAG=$1
    local DOCKERFILE=${2:-Dockerfile}
    local CONTEXT=${3:-.}
    
    echo "Building image: $TAG"
    echo "Dockerfile: $DOCKERFILE"
    echo "Build context: $CONTEXT"
    echo
    
    # Show the built image info
    if docker build -t "$TAG" -f "$DOCKERFILE" "$CONTEXT"; then
        echo
        echo "---[ Built Image Info ]----------------------------"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | head -1
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | grep "$(echo "$TAG" | cut -d: -f1)"
    fi
}


jwdocker_image-rm() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker images --format "{{.Repository}}:{{.Tag}}"
        echo
        return 1
    fi

    local IMAGE=$1
    local FORCE=${2:-false}
    
    # Safety check - don't remove images that are being used by containers
    local using_containers
    using_containers=$(docker ps -a --filter ancestor="$IMAGE" --format "{{.Names}}")
    
    if [ -n "$using_containers" ]; then
        if [ "$FORCE" != "force" ] && [ "$FORCE" != "-f" ]; then
            echo "Error: Image '$IMAGE' is being used by containers:"
            while IFS= read -r container; do
                echo " - $container"
            done <<< "$using_containers"
            echo "Remove containers first or use 'force' flag."
            echo "Usage: jwdockerrmi $IMAGE force"
            return 1
        fi
        echo "Force removing image used by containers: $IMAGE"
        docker rmi -f "$IMAGE"
    else
        echo "Removing image: $IMAGE"
        docker rmi "$IMAGE"
    fi
}


jwdocker_image-history() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        echo "Usage: jwdockerimagehistory <image> [--no-trunc]"
        echo
        docker images --format "{{.Repository}}:{{.Tag}}"
        echo
        return 1
    fi

    local IMAGE=$1
    local TRUNC_FLAG=""
    
    # Check if second parameter is --no-trunc
    if [ "$2" = "--no-trunc" ]; then
        TRUNC_FLAG="--no-trunc"
    fi

    echo
    echo "---[ Image History: $IMAGE ]----------------------"
    docker history $TRUNC_FLAG --format "table {{.CreatedBy}}\t{{.Size}}\t{{.CreatedSince}}" "$IMAGE"
    echo
}


# ---------------------------------------------------------------------------------
# volume management
# ---------------------------------------------------------------------------------

jwdocker_volumes() {
    if [ $# -eq 0 ]; then
        # Show all volumes with clean formatting
        docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
    else
        # Filter volumes by name
        docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | head -1
        docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | grep -i "$1"
    fi
}


jwdocker_volume-inspect() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker volume ls --format "{{.Name}}"
        echo
        return 1
    fi

    local VOLUME=$1
    echo
    echo "---[ Volume: $VOLUME ]-----------------------------"
    docker volume inspect --format 'Name:       {{ .Name }}' "$VOLUME"
    docker volume inspect --format 'Driver:     {{ .Driver }}' "$VOLUME"
    docker volume inspect --format 'Mountpoint: {{ .Mountpoint }}' "$VOLUME"
    docker volume inspect --format 'Scope:      {{ .Scope }}' "$VOLUME"
    docker volume inspect --format 'Created:    {{ .CreatedAt }}' "$VOLUME"
    echo
    echo "---[ Labels ]--------------------------------------"
    docker volume inspect --format '{{ range $key, $value := .Labels }}{{ printf "  %-30s" $key }}{{ $value }}{{ printf "\n" }}{{ end }}' "$VOLUME"
    echo
    echo "---[ Options ]-------------------------------------"
    docker volume inspect --format '{{ range $key, $value := .Options }}{{ printf "  %-30s" $key }}{{ $value }}{{ printf "\n" }}{{ end }}' "$VOLUME"
    echo
    
    # Show which containers are using this volume
    echo "---[ Used By ]-------------------------------------"
    local using_containers
    using_containers=$(docker ps -a --filter volume="$VOLUME" --format "{{.Names}}")
    if [ -n "$using_containers" ]; then
        while IFS= read -r container; do
            echo " - $container"
        done <<< "$using_containers"
    else
        echo "  (not currently used by any containers)"
    fi
    echo
}


jwdocker_volume-create() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockervolumecreate <volume_name> [driver] [options]"
        echo "Examples:"
        echo "  jwdockervolumecreate mydata"
        echo "  jwdockervolumecreate mydata local"
        echo "  jwdockervolumecreate mydata local --opt type=tmpfs"
        return 1
    fi

    local VOLUME_NAME=$1
    local DRIVER=${2:-local}
    shift 2  # Remove volume name and driver from arguments
    local OPTIONS="$*"
    
    echo "Creating volume: $VOLUME_NAME"
    echo "Driver: $DRIVER"
    # Show the created volume info
    if [ -n "$OPTIONS" ]; then
        echo "Options: $OPTIONS"
        # shellcheck disable=SC2086
        docker volume create --driver "$DRIVER" $OPTIONS "$VOLUME_NAME"
    else
        docker volume create --driver "$DRIVER" "$VOLUME_NAME"
    fi && {
        echo
        echo "---[ Created Volume Info ]-------------------------"
        docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | head -1
        docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | grep "^$VOLUME_NAME"
    }
}


jwdocker_volume-remove() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker volume ls --format "{{.Name}}"
        echo
        return 1
    fi

    local VOLUME=$1
    local FORCE=${2:-false}
    
    # Safety check - don't remove volumes that are being used by containers
    local using_containers
    using_containers=$(docker ps -a --filter volume="$VOLUME" --format "{{.Names}}")
    
    if [ -n "$using_containers" ]; then
        if [ "$FORCE" != "force" ] && [ "$FORCE" != "-f" ]; then
            echo "Error: Volume '$VOLUME' is being used by containers:"
            while IFS= read -r container; do
                echo " - $container"
            done <<< "$using_containers"
            echo "Remove containers first or use 'force' flag."
            echo "Usage: jwdockervolumeremove $VOLUME force"
            return 1
        fi
        echo "Force removing volume used by containers: $VOLUME"
        docker volume rm -f "$VOLUME"
    else
        echo "Removing volume: $VOLUME"
        docker volume rm "$VOLUME"
    fi
}


jwdocker_volume-prune() {
    echo "This will remove all unused local volumes."
    echo -n "Are you sure? [y/N] "
    read -r response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo "Pruning unused volumes..."
        docker volume prune -f
        echo "Volume pruning complete."
    else
        echo "Operation cancelled."
    fi
}


# ---------------------------------------------------------------------------------
# network management
# ---------------------------------------------------------------------------------

jwdocker_networks() {
    if [ $# -eq 0 ]; then
        # Show all networks with clean formatting
        docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
    else
        # Filter networks by name
        docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | head -1
        docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | grep -i "$1"
    fi
}


jwdocker_network-create() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockernetworkcreate <network_name> [driver] [options]"
        echo "Examples:"
        echo "  jwdockernetworkcreate mynetwork"
        echo "  jwdockernetworkcreate mynetwork bridge"
        echo "  jwdockernetworkcreate mynetwork bridge --subnet=172.20.0.0/16"
        echo "  jwdockernetworkcreate mynetwork overlay --attachable"
        return 1
    fi

    local NETWORK_NAME=$1
    local DRIVER=${2:-bridge}
    shift 2  # Remove network name and driver from arguments
    local OPTIONS="$*"
    
    echo "Creating network: $NETWORK_NAME"
    echo "Driver: $DRIVER"
    # Show the created network info
    if [ -n "$OPTIONS" ]; then
        echo "Options: $OPTIONS"
        # shellcheck disable=SC2086
        docker network create --driver "$DRIVER" $OPTIONS "$NETWORK_NAME"
    else
        docker network create --driver "$DRIVER" "$NETWORK_NAME"
    fi && {
        echo
        echo "---[ Created Network Info ]------------------------"
        docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | head -1
        docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | grep "^$NETWORK_NAME"
    }
}


jwdocker_network-remove() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        echo "Available networks (excluding system networks):"
        docker network ls --filter type=custom --format "- {{.Name}}"
        echo
        return 1
    fi

    local NETWORK=$1
    local FORCE=${2:-false}
    
    # Safety check - don't remove networks that are being used by containers
    local using_containers
    using_containers=$(docker network inspect "$NETWORK" --format '{{ range $key, $value := .Containers }}{{.Name}} {{ end }}' 2>/dev/null)
    
    if [ -n "$using_containers" ]; then
        if [ "$FORCE" != "force" ] && [ "$FORCE" != "-f" ]; then
            echo "Error: Network '$NETWORK' is being used by containers:"
            echo "$using_containers" | tr ' ' '\n' | sed 's/^/ - /' | grep -v '^$'
            echo "Disconnect containers first or use 'force' flag."
            echo "Usage: jwdockernetworkremove $NETWORK force"
            return 1
        fi
        echo "Force removing network used by containers: $NETWORK"
        docker network rm "$NETWORK" 2>/dev/null || echo "Failed to remove network (may be in use)"
    else
        echo "Removing network: $NETWORK"
        docker network rm "$NETWORK"
    fi
}


jwdocker_network-connect() {
    if [ $# -lt 2 ]; then
        echo "Usage: jwdockernetworkconnect <network> <container> [options]"
        echo "Examples:"
        echo "  jwdockernetworkconnect mynetwork mycontainer"
        echo "  jwdockernetworkconnect mynetwork mycontainer --ip=172.20.0.10"
        echo "  jwdockernetworkconnect mynetwork mycontainer --alias=web"
        echo
        echo "Available networks:"
        docker network ls --format "- {{.Name}}"
        echo
        echo "Available containers:"
        docker ps -a --format "- {{.Names}}"
        echo
        return 1
    fi

    local NETWORK=$1
    local CONTAINER=$2
    shift 2  # Remove network and container from arguments
    local OPTIONS="$*"
    
    echo "Connecting container '$CONTAINER' to network '$NETWORK'"
    # Show the connection info
    if [ -n "$OPTIONS" ]; then
        echo "Options: $OPTIONS"
        # shellcheck disable=SC2086
        docker network connect $OPTIONS "$NETWORK" "$CONTAINER"
    else
        docker network connect "$NETWORK" "$CONTAINER"
    fi && {
        echo
        echo "---[ Connection Info ]-----------------------------"
        docker inspect "$CONTAINER" --format '{{ range $key, $value := .NetworkSettings.Networks }}{{printf "%s: %s\n" $key .IPAddress}}{{ end }}' | grep "$NETWORK"
    }
}


jwdocker_network-disconnect() {
    if [ $# -lt 2 ]; then
        echo "Usage: jwdockernetworkdisconnect <network> <container> [force]"
        echo "Examples:"
        echo "  jwdockernetworkdisconnect mynetwork mycontainer"
        echo "  jwdockernetworkdisconnect mynetwork mycontainer force"
        echo
        echo "Available networks:"
        docker network ls --format "- {{.Name}}"
        echo
        echo "Available containers:"
        docker ps -a --format "- {{.Names}}"
        echo
        return 1
    fi

    local NETWORK=$1
    local CONTAINER=$2
    local FORCE=${3:-false}
    
    echo "Disconnecting container '$CONTAINER' from network '$NETWORK'"
    if [ "$FORCE" = "force" ] || [ "$FORCE" = "-f" ]; then
        docker network disconnect --force "$NETWORK" "$CONTAINER"
    else
        docker network disconnect "$NETWORK" "$CONTAINER"
    fi
}


jwdocker_network-prune() {
    echo "This will remove all unused networks."
    echo -n "Are you sure? [y/N] "
    read -r response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo "Pruning unused networks..."
        docker network prune -f
        echo "Network pruning complete."
    else
        echo "Operation cancelled."
    fi
}


# ---------------------------------------------------------------------------------
# resource monitoring
# ---------------------------------------------------------------------------------

jwdocker_monitor-stats() {
    if [ $# -eq 0 ]; then
        # Show stats for all running containers with clean formatting
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    else
        # Show stats for specific container(s)
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" "$@"
    fi
}


jwdocker_monitor-top() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker ps --filter status=running --format "{{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    echo
    echo "---[ Processes in $CONTAINER ]-------------------------"
    docker top "$CONTAINER"
    echo
}


jwdocker_monitor-health() {
    echo
    echo "---[ Container Health Status ]-------------------------"
    docker ps --format "table {{.Names}}\t{{.Status}}" | head -1
    docker ps --format "table {{.Names}}\t{{.Status}}" | tail -n +2 | while read -r name container_status; do
        if echo "$container_status" | grep -q "healthy"; then
            echo -e "$name\t\033[32m$container_status\033[0m"
        elif echo "$container_status" | grep -q "unhealthy"; then
            echo -e "$name\t\033[31m$container_status\033[0m"
        elif echo "$container_status" | grep -q "starting"; then
            echo -e "$name\t\033[33m$container_status\033[0m"
        else
            echo -e "$name\t$container_status"
        fi
    done
    echo
}


# ---------------------------------------------------------------------------------
# system cleanup & maintenance
# ---------------------------------------------------------------------------------

jwdocker_disk-usage() {
    echo
    echo "---[ Docker Disk Usage ]---------------------------"
    docker system df
    echo
    echo "---[ Detailed Breakdown ]-------------------------"
    docker system df -v
    echo
}


jwdocker_system-info() {
    echo
    echo "---[ Docker System Information ]-------------------"
    docker version --format "Client Version: {{.Client.Version}}"
    docker version --format "Server Version: {{.Server.Version}}"
    echo
    docker info --format "Containers: {{.Containers}} ({{.ContainersRunning}} running, {{.ContainersPaused}} paused, {{.ContainersStopped}} stopped)"
    docker info --format "Images: {{.Images}}"
    docker info --format "Server Version: {{.ServerVersion}}"
    docker info --format "Storage Driver: {{.Driver}}"
    docker info --format "Docker Root Dir: {{.DockerRootDir}}"
    echo
    echo "---[ Resource Usage ]------------------------------"
    docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}"
    echo
}


jwdocker_prune() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockerprune [containers|images|volumes|networks|system|all]"
        echo "Examples:"
        echo "  jwdockerprune containers  # Remove stopped containers"
        echo "  jwdockerprune images      # Remove unused images"
        echo "  jwdockerprune volumes     # Remove unused volumes"
        echo "  jwdockerprune networks    # Remove unused networks"
        echo "  jwdockerprune system      # Remove containers, networks, images (not volumes)"
        echo "  jwdockerprune all         # Remove everything unused (including volumes)"
        return 1
    fi

    local TYPE=$1
    
    case $TYPE in
        containers)
            echo "This will remove all stopped containers."
            echo -n "Are you sure? [y/N] "
            read -r response
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                echo "Pruning stopped containers..."
                docker container prune -f
                echo "Container pruning complete."
            else
                echo "Operation cancelled."
            fi
            ;;
        images)
            echo "This will remove all unused images (not referenced by any container)."
            echo -n "Are you sure? [y/N] "
            read -r response
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                echo "Pruning unused images..."
                docker image prune -f
                echo "Image pruning complete."
            else
                echo "Operation cancelled."
            fi
            ;;
        volumes)
            jwdockervolumeprune
            ;;
        networks)
            jwdockernetworkprune
            ;;
        system)
            echo "This will remove:"
            echo " - All stopped containers"
            echo " - All networks not used by at least one container"
            echo " - All unused images"
            echo " - All build cache"
            echo
            echo "NOTE: This will NOT remove volumes."
            echo -n "Are you sure? [y/N] "
            read -r response
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                echo "Performing system prune..."
                docker system prune -f
                echo "System pruning complete."
            else
                echo "Operation cancelled."
            fi
            ;;
        all)
            echo "⚠️  WARNING: This will remove:"
            echo " - All stopped containers"
            echo " - All networks not used by at least one container"
            echo " - All unused images"
            echo " - All unused volumes"
            echo " - All build cache"
            echo
            echo "This is a destructive operation that will free up maximum space."
            echo -n "Are you absolutely sure? [y/N] "
            read -r response
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                echo "Performing complete system prune..."
                docker system prune -a --volumes -f
                echo "Complete system pruning finished."
            else
                echo "Operation cancelled."
            fi
            ;;
        *)
            echo "Error: Unknown prune type '$TYPE'"
            echo "Valid types: containers, images, volumes, networks, system, all"
            return 1
            ;;
    esac
}


jwdocker_cleanup() {
    echo "🧹 Docker Cleanup Wizard"
    echo "========================"
    echo
    
    # Show current disk usage
    echo "Current Docker disk usage:"
    docker system df
    echo
    
    # Show what can be cleaned
    echo "Available cleanup options:"
    echo
    
    # Check for stopped containers
    local stopped_containers
    stopped_containers=$(docker ps -a --filter status=exited --filter status=created --format "{{.Names}}" | wc -l)
    echo "1. Stopped containers: $stopped_containers"
    
    # Check for unused images
    local unused_images
    unused_images=$(docker images --filter dangling=true -q | wc -l)
    echo "2. Unused/dangling images: $unused_images"
    
    # Check for unused volumes
    local unused_volumes
    unused_volumes=$(docker volume ls --filter dangling=true -q | wc -l)
    echo "3. Unused volumes: $unused_volumes"
    
    # Check for unused networks
    local unused_networks
    unused_networks=$(docker network ls --filter dangling=true -q | wc -l)
    echo "4. Unused networks: $unused_networks"
    
    echo
    echo "Cleanup options:"
    echo "  a) Clean stopped containers only"
    echo "  b) Clean unused images only"
    echo "  c) Clean unused volumes only"
    echo "  d) Clean unused networks only"
    echo "  e) Clean containers + images + networks (safe)"
    echo "  f) Clean everything including volumes (⚠️  destructive)"
    echo "  q) Quit without cleaning"
    echo
    echo -n "Choose an option [a/b/c/d/e/f/q]: "
    read -r choice
    
    case $choice in
        a|A)
            jwdockerprune containers
            ;;
        b|B)
            jwdockerprune images
            ;;
        c|C)
            jwdockerprune volumes
            ;;
        d|D)
            jwdockerprune networks
            ;;
        e|E)
            jwdockerprune system
            ;;
        f|F)
            jwdockerprune all
            ;;
        q|Q)
            echo "Cleanup cancelled."
            ;;
        *)
            echo "Invalid option. Cleanup cancelled."
            return 1
            ;;
    esac
    
    # Show final disk usage if cleanup was performed
    if [ "$choice" != "q" ] && [ "$choice" != "Q" ]; then
        echo
        echo "Final Docker disk usage:"
        docker system df
    fi
}


jwdocker_size() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockersize [containers|images|volumes|all]"
        echo "Examples:"
        echo "  jwdockersize containers  # Show container sizes"
        echo "  jwdockersize images      # Show image sizes"
        echo "  jwdockersize volumes     # Show volume sizes"
        echo "  jwdockersize all         # Show everything"
        return 1
    fi

    local TYPE=$1
    
    case $TYPE in
        containers)
            echo
            echo "---[ Container Sizes ]---------------------------------"
            docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Size}}"
            ;;
        images)
            echo
            echo "---[ Image Sizes ]-------------------------------------"
            docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
            ;;
        volumes)
            echo
            echo "---[ Volume Sizes ]------------------------------------"
            docker system df -v | grep -A 100 "Local Volumes" | tail -n +3
            ;;
        all)
            jwdockersize containers
            jwdockersize images
            jwdockersize volumes
            echo
            echo "---[ Summary ]------------------------------------------"
            docker system df
            ;;
        *)
            echo "Error: Unknown size type '$TYPE'"
            echo "Valid types: containers, images, volumes, all"
            return 1
            ;;
    esac
    echo
}


# ---------------------------------------------------------------------------------
# import/export utilities
# ---------------------------------------------------------------------------------

jwdocker_save() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockersave <image> [output_file]"
        echo "Examples:"
        echo "  jwdockersave nginx                    # Saves to nginx.tar"
        echo "  jwdockersave nginx:alpine             # Saves to nginx_alpine.tar"
        echo "  jwdockersave nginx /tmp/nginx.tar     # Saves to specific file"
        echo
        echo "Available images:"
        docker images --format "- {{.Repository}}:{{.Tag}}"
        echo
        return 1
    fi

    local IMAGE=$1
    local OUTPUT_FILE=$2
    
    # Generate default filename if not provided
    if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE=$(echo "$IMAGE" | tr ':/' '_').tar
    fi
    
    echo "Saving image '$IMAGE' to '$OUTPUT_FILE'..."
    if docker save -o "$OUTPUT_FILE" "$IMAGE"; then
        echo "Image saved successfully!"
        echo "File: $OUTPUT_FILE"
        echo "Size: $(stat -c%s "$OUTPUT_FILE" | numfmt --to=iec)"
    else
        echo "Failed to save image."
        return 1
    fi
}


jwdocker_load() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockerload <tar_file>"
        echo "Examples:"
        echo "  jwdockerload nginx.tar"
        echo "  jwdockerload /tmp/myimage.tar"
        echo
        echo "Available tar files in current directory:"
        ls -1 ./*.tar 2>/dev/null || echo "  (no .tar files found)"
        echo
        return 1
    fi

    local TAR_FILE=$1
    
    if [ ! -f "$TAR_FILE" ]; then
        echo "Error: File '$TAR_FILE' not found."
        return 1
    fi
    
    echo "Loading image from '$TAR_FILE'..."
    echo "File size: $(stat -c%s "$TAR_FILE" | numfmt --to=iec)"
    echo
    
    if docker load -i "$TAR_FILE"; then
        echo
        echo "---[ Loaded Images ]--------------------------------"
        echo "Recent images (last 5):"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | head -6
    else
        echo "Failed to load image."
        return 1
    fi
}


jwdocker_export() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockerexport <container> [output_file]"
        echo "Examples:"
        echo "  jwdockerexport mycontainer                    # Exports to mycontainer.tar"
        echo "  jwdockerexport mycontainer /tmp/backup.tar    # Exports to specific file"
        echo
        echo "Available containers:"
        docker ps -a --format "- {{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    local OUTPUT_FILE=$2
    
    # Generate default filename if not provided
    if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="${CONTAINER}.tar"
    fi
    
    echo "Exporting container '$CONTAINER' to '$OUTPUT_FILE'..."
    if docker export -o "$OUTPUT_FILE" "$CONTAINER"; then
        echo "Container exported successfully!"
        echo "File: $OUTPUT_FILE"
        echo "Size: $(stat -c%s "$OUTPUT_FILE" | numfmt --to=iec)"
    else
        echo "Failed to export container."
        return 1
    fi
}


jwdocker_import() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockerimport <tar_file> [repository[:tag]]"
        echo "Examples:"
        echo "  jwdockerimport container.tar                    # Imports as <none>:<none>"
        echo "  jwdockerimport container.tar myimage:latest     # Imports with specific name"
        echo
        echo "Available tar files in current directory:"
        ls -1 ./*.tar 2>/dev/null || echo "  (no .tar files found)"
        echo
        return 1
    fi

    local TAR_FILE=$1
    local REPOSITORY=$2
    
    if [ ! -f "$TAR_FILE" ]; then
        echo "Error: File '$TAR_FILE' not found."
        return 1
    fi
    
    echo "Importing container from '$TAR_FILE'..."
    echo "File size: $(stat -c%s "$TAR_FILE" | numfmt --to=iec)"
    
    if [ -n "$REPOSITORY" ]; then
        echo "Repository: $REPOSITORY"
        if docker import "$TAR_FILE" "$REPOSITORY"; then
            echo
            echo "---[ Imported Image ]-------------------------------"
            echo "Recent images (last 5):"
            docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | head -6
        else
            echo "Failed to import container."
            return 1
        fi
    else
        echo "Repository: (will be <none>:<none>)"
        if docker import "$TAR_FILE"; then
            echo
            echo "---[ Imported Image ]-------------------------------"
            echo "Recent images (last 5):"
            docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | head -6
        else
            echo "Failed to import container."
            return 1
        fi
    fi
}


# ---------------------------------------------------------------------------------
# quick utility functions
# ---------------------------------------------------------------------------------

jwdocker_search() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockersearch <search_term> [limit]"
        echo "Examples:"
        echo "  jwdockersearch nginx"
        echo "  jwdockersearch nginx 10"
        echo "  jwdockersearch ubuntu/nginx"
        return 1
    fi

    local SEARCH_TERM=$1
    local LIMIT=${2:-25}
    
    echo "Searching Docker Hub for '$SEARCH_TERM' (limit: $LIMIT)..."
    echo
    docker search --limit="$LIMIT" "$SEARCH_TERM"
    echo
}


jwdocker_backup() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockerbackup <container> [backup_dir]"
        echo "Examples:"
        echo "  jwdockerbackup mycontainer"
        echo "  jwdockerbackup mycontainer /backups"
        echo
        echo "This will create a backup containing:"
        echo "  - Container export (filesystem)"
        echo "  - Container configuration"
        echo "  - Associated volumes (if any)"
        echo
        echo "Available containers:"
        docker ps -a --format "- {{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    local BACKUP_DIR=${2:-./docker-backups}
    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_PATH="$BACKUP_DIR/${CONTAINER}_${TIMESTAMP}"
    
    echo "Creating backup for container '$CONTAINER'..."
    echo "Backup location: $BACKUP_PATH"
    
    # Create backup directory
    mkdir -p "$BACKUP_PATH"
    
    # Export container filesystem
    echo "Exporting container filesystem..."
    docker export -o "$BACKUP_PATH/${CONTAINER}_filesystem.tar" "$CONTAINER"
    
    # Save container configuration
    echo "Saving container configuration..."
    docker inspect "$CONTAINER" > "$BACKUP_PATH/${CONTAINER}_config.json"
    
    # Get image information
    local IMAGE
    IMAGE=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER")
    echo "Saving image information..."
    echo "Image: $IMAGE" > "$BACKUP_PATH/${CONTAINER}_image.txt"
    
    # List volumes
    echo "Documenting volumes..."
    docker inspect --format='{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Type}}){{"\n"}}{{end}}' "$CONTAINER" > "$BACKUP_PATH/${CONTAINER}_volumes.txt"
    
    # Create restore script
    echo "Creating restore script..."
    cat > "$BACKUP_PATH/restore.sh" << EOF
#!/bin/bash
# Restore script for container: $CONTAINER
# Created: $(date)

echo "Restoring container $CONTAINER..."

# Import the filesystem as a new image
echo "Importing filesystem..."
docker import ${CONTAINER}_filesystem.tar ${CONTAINER}_restored:latest

# Note: You may need to manually recreate volumes and networks
echo "Container filesystem imported as ${CONTAINER}_restored:latest"
echo "Check ${CONTAINER}_config.json for original configuration"
echo "Check ${CONTAINER}_volumes.txt for volume mappings"
echo "You may need to manually recreate the container with appropriate options"
EOF
    chmod +x "$BACKUP_PATH/restore.sh"
    
    # Show backup summary
    echo
    echo "---[ Backup Complete ]------------------------------"
    echo "Location: $BACKUP_PATH"
    echo "Files created:"
    ls -lh "$BACKUP_PATH"
    echo
    echo "Total backup size: $(du -sh "$BACKUP_PATH" | cut -f1)"
    echo
}


jwdocker_cp() {
    if [ $# -lt 2 ]; then
        echo "Usage: jwdockercp <source> <destination>"
        echo "Examples:"
        echo "  jwdockercp mycontainer:/app/config.txt ./config.txt"
        echo "  jwdockercp ./data.json mycontainer:/tmp/data.json"
        echo "  jwdockercp mycontainer:/logs/ ./container-logs/"
        echo
        echo "Available containers:"
        docker ps -a --format "- {{.Names}}"
        echo
        return 1
    fi

    local SOURCE=$1
    local DESTINATION=$2
    
    echo "Copying from '$SOURCE' to '$DESTINATION'..."
    if docker cp "$SOURCE" "$DESTINATION"; then
        echo "Copy completed successfully!"
        
        # Show destination info if it's a local path
        if [[ "$DESTINATION" != *":"* ]]; then
            if [ -f "$DESTINATION" ]; then
                echo "File size: $(stat -c%s "$DESTINATION" | numfmt --to=iec)"
            elif [ -d "$DESTINATION" ]; then
                echo "Directory contents: $(find "$DESTINATION" -maxdepth 1 -type f | wc -l) items"
            fi
        fi
    else
        echo "Copy failed!"
        return 1
    fi
}


jwdocker_run() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockerrun <image> [options]"
        echo "Examples:"
        echo "  jwdockerrun nginx"
        echo "  jwdockerrun nginx -p 8080:80"
        echo "  jwdockerrun ubuntu:20.04 -it --rm bash"
        echo "  jwdockerrun postgres:13 -e POSTGRES_PASSWORD=secret"
        echo
        echo "Common options:"
        echo "  -d, --detach          Run in background"
        echo "  -it                   Interactive with TTY"
        echo "  --rm                  Remove container when it exits"
        echo "  -p <host>:<container> Port mapping"
        echo "  -v <host>:<container> Volume mapping"
        echo "  -e <VAR>=<value>      Environment variable"
        echo "  --name <name>         Container name"
        echo
        return 1
    fi

    local IMAGE=$1
    shift  # Remove image from arguments
    local OPTIONS="$*"
    
    echo "Running container from image '$IMAGE'..."
    if [ -n "$OPTIONS" ]; then
        echo "Options: $OPTIONS"
        # shellcheck disable=SC2086
        docker run $OPTIONS "$IMAGE"
    else
        echo "Using default options: -d (detached)"
        docker run -d "$IMAGE"
    fi && {
        # Show the new container if it was created
        echo
        echo "---[ New Container ]--------------------------------"
        docker ps -l --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    }
}


jwdocker_tag() {
    if [ $# -lt 2 ]; then
        echo "Usage: jwdockertag <source_image> <target_image>"
        echo "Examples:"
        echo "  jwdockertag nginx:latest myregistry.com/nginx:v1.0"
        echo "  jwdockertag myapp:latest myapp:production"
        echo "  jwdockertag ubuntu:20.04 ubuntu:focal"
        echo
        echo "Available images:"
        docker images --format "- {{.Repository}}:{{.Tag}}"
        echo
        return 1
    fi

    local SOURCE_IMAGE=$1
    local TARGET_IMAGE=$2
    
    echo "Tagging '$SOURCE_IMAGE' as '$TARGET_IMAGE'..."
    if docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"; then
        echo "Image tagged successfully!"
        echo
        echo "---[ Tagged Images ]--------------------------------"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | head -1
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | grep "$(echo "$TARGET_IMAGE" | cut -d: -f1)"
    else
        echo "Tagging failed!"
        return 1
    fi
}


jwdocker_push() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockerpush <image>"
        echo "Examples:"
        echo "  jwdockerpush myregistry.com/myapp:latest"
        echo "  jwdockerpush username/myimage:v1.0"
        echo
        echo "Available images:"
        docker images --format "- {{.Repository}}:{{.Tag}}"
        echo
        return 1
    fi

    local IMAGE=$1
    
    echo "Pushing image '$IMAGE' to registry..."
    if docker push "$IMAGE"; then
        echo "Image pushed successfully!"
    else
        echo "Push failed! Make sure you're logged in to the registry."
        echo "Use: docker login [registry-url]"
        return 1
    fi
}


jwdocker_connectivity() {
    if [ $# -lt 2 ]; then
        echo "Usage: jwdockerconnectivity <source_container> <target_container> [port]"
        echo "Examples:"
        echo "  jwdockerconnectivity web database"
        echo "  jwdockerconnectivity web api 8080"
        echo "  jwdockerconnectivity frontend backend 3000"
        echo
        echo "This will:"
        echo "  - Show shared networks between containers"
        echo "  - Display IP addresses on each network"
        echo "  - Test basic connectivity (ping)"
        echo "  - Test port connectivity if specified"
        echo
        echo "Available running containers:"
        docker ps --format "- {{.Names}}"
        echo
        return 1
    fi

    local SOURCE_CONTAINER=$1
    local TARGET_CONTAINER=$2
    local PORT=$3
    
    # Check if both containers exist and are running
    if ! docker ps --format "{{.Names}}" | grep -q "^${SOURCE_CONTAINER}$"; then
        echo "Error: Source container '$SOURCE_CONTAINER' is not running."
        return 1
    fi
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${TARGET_CONTAINER}$"; then
        echo "Error: Target container '$TARGET_CONTAINER' is not running."
        return 1
    fi
    
    echo "🔍 Testing connectivity: $SOURCE_CONTAINER → $TARGET_CONTAINER"
    echo "============================================================"
    echo
    
    # Get network information for both containers
    echo "---[ Network Analysis ]-----------------------------"
    
    # Get networks for source container
    local source_networks
    source_networks=$(docker inspect "$SOURCE_CONTAINER" --format '{{ range $key, $value := .NetworkSettings.Networks }}{{$key}}:{{.IPAddress}}{{ printf "\n" }}{{ end }}')
    echo "Source ($SOURCE_CONTAINER) networks:"
    while IFS=: read -r network ip; do
        if [ -n "$network" ]; then
            echo "  - $network: $ip"
        fi
    done <<< "$source_networks"
    echo
    
    # Get networks for target container
    local target_networks
    target_networks=$(docker inspect "$TARGET_CONTAINER" --format '{{ range $key, $value := .NetworkSettings.Networks }}{{$key}}:{{.IPAddress}}{{ printf "\n" }}{{ end }}')
    echo "Target ($TARGET_CONTAINER) networks:"
    while IFS=: read -r network ip; do
        if [ -n "$network" ]; then
            echo "  - $network: $ip"
        fi
    done <<< "$target_networks"
    echo
    
    # Find shared networks
    echo "---[ Shared Networks ]------------------------------"
    local shared_networks=""
    local target_ips=""
    
    while IFS=: read -r source_network _source_ip; do
        if [ -n "$source_network" ]; then
            while IFS=: read -r target_network target_ip; do
                if [ -n "$target_network" ] && [ "$source_network" = "$target_network" ]; then
                    echo "  ✅ $source_network (target IP: $target_ip)"
                    shared_networks="$shared_networks $source_network"
                    target_ips="$target_ips $target_ip"
                fi
            done <<< "$target_networks"
        fi
    done <<< "$source_networks"
    
    if [ -z "$shared_networks" ]; then
        echo "  ❌ No shared networks found!"
        echo
        echo "💡 To enable connectivity, connect both containers to the same network:"
        echo "   jwdockernetworkconnect <network_name> $SOURCE_CONTAINER"
        echo "   jwdockernetworkconnect <network_name> $TARGET_CONTAINER"
        return 1
    fi
    echo
    
    # Test connectivity
    echo "---[ Connectivity Tests ]---------------------------"
    
    # Test ping connectivity to each shared network IP
    for target_ip in $target_ips; do
        if [ -n "$target_ip" ] && [ "$target_ip" != "<no value>" ]; then
            echo -n "Ping test to $target_ip: "
            if docker exec "$SOURCE_CONTAINER" ping -c 1 -W 2 "$target_ip" >/dev/null 2>&1; then
                echo "✅ SUCCESS"
            else
                echo "❌ FAILED"
            fi
        fi
    done
    
    # Test hostname resolution
    echo -n "Hostname resolution ($TARGET_CONTAINER): "
    if docker exec "$SOURCE_CONTAINER" ping -c 1 -W 2 "$TARGET_CONTAINER" >/dev/null 2>&1; then
        echo "✅ SUCCESS"
    else
        echo "❌ FAILED"
    fi
    
    # Test port connectivity if specified
    if [ -n "$PORT" ]; then
        echo
        echo "---[ Port Connectivity Test ]-----------------------"
        for target_ip in $target_ips; do
            if [ -n "$target_ip" ] && [ "$target_ip" != "<no value>" ]; then
                echo -n "Port $PORT test to $target_ip: "
                # Try to connect to the port using nc (netcat) or telnet
                if docker exec "$SOURCE_CONTAINER" sh -c "command -v nc >/dev/null 2>&1"; then
                    if docker exec "$SOURCE_CONTAINER" nc -z -w 2 "$target_ip" "$PORT" >/dev/null 2>&1; then
                        echo "✅ SUCCESS (port is open)"
                    else
                        echo "❌ FAILED (port is closed or filtered)"
                    fi
                elif docker exec "$SOURCE_CONTAINER" sh -c "command -v telnet >/dev/null 2>&1"; then
                    if timeout 2 docker exec "$SOURCE_CONTAINER" telnet "$target_ip" "$PORT" >/dev/null 2>&1; then
                        echo "✅ SUCCESS (port is open)"
                    else
                        echo "❌ FAILED (port is closed or filtered)"
                    fi
                else
                    echo "⚠️  SKIPPED (no nc or telnet available in source container)"
                fi
            fi
        done
        
        # Test port via hostname
        echo -n "Port $PORT test to $TARGET_CONTAINER: "
        if docker exec "$SOURCE_CONTAINER" sh -c "command -v nc >/dev/null 2>&1"; then
            if docker exec "$SOURCE_CONTAINER" nc -z -w 2 "$TARGET_CONTAINER" "$PORT" >/dev/null 2>&1; then
                echo "✅ SUCCESS (port is open)"
            else
                echo "❌ FAILED (port is closed or filtered)"
            fi
        elif docker exec "$SOURCE_CONTAINER" sh -c "command -v telnet >/dev/null 2>&1"; then
            if timeout 2 docker exec "$SOURCE_CONTAINER" telnet "$TARGET_CONTAINER" "$PORT" >/dev/null 2>&1; then
                echo "✅ SUCCESS (port is open)"
            else
                echo "❌ FAILED (port is closed or filtered)"
            fi
        else
            echo "⚠️  SKIPPED (no nc or telnet available in source container)"
        fi
    fi
    
    echo
    echo "---[ Summary ]--------------------------------------"
    if [ -n "$shared_networks" ]; then
        echo "✅ Containers can communicate via shared networks"
        if [ -n "$PORT" ]; then
            echo "🔍 Port $PORT connectivity tested above"
        fi
    else
        echo "❌ Containers cannot communicate (no shared networks)"
    fi
    echo
}



# ---------------------------------------------------------------------------------
# troubleshooting tools
# ---------------------------------------------------------------------------------

jwdocker_exec() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker ps --filter status=running --format "{{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    local SHELL=${2:-/bin/bash}
    
    echo "Connecting to $CONTAINER with $SHELL..."
    docker exec -it "$CONTAINER" "$SHELL"
}


jwdocker_logs() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker ps -a --format "{{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    local LINES=${2:-50}
    
    echo
    echo "---[ Last $LINES lines from $CONTAINER ]---------------"
    docker logs --tail "$LINES" "$CONTAINER"
    echo
}


jwdocker_port() {
    if [ $# -eq 0 ]; then
        echo
        echo "---[ Port Mappings ]--------------------------------"
        docker ps --format "table {{.Names}}\t{{.Ports}}"
        echo
    else
        local CONTAINER=$1
        echo
        echo "---[ Ports for $CONTAINER ]------------------------"
        docker port "$CONTAINER"
        echo
    fi
}
