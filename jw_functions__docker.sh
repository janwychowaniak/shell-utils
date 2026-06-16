# shellcheck shell=bash


# ---------------------------------------------------------------------------------
# table of contents
# ---------------------------------------------------------------------------------

jwdocker_toc() {
    echo
    echo "   blast radius:  🟢 tylko odczyt   🔵 tworzy   ⚪ zmiana stanu / transfer   🔴 kasuje (destructive)"
    echo
    echo " -----------------------------  legacy: aliases"
    echo " - 🟢 jwdocker_findcontainerbyip"
    echo
    echo " -----------------------------  ps"
    echo " - 🟢 jwdocker_ps"
    echo " - 🟢 jwdocker_psup"
    echo " - 🟢 jwdocker_psall"
    echo " - 🟢 jwdocker_psdown"
    echo
    echo " -----------------------------  container lifecycle management"
    echo " - 🟢 jwdocker_containers"
    echo " - ⚪ jwdocker_container-start"
    echo " - ⚪ jwdocker_container-stop"
    echo " - ⚪ jwdocker_container-restart"
    echo " - 🔴 jwdocker_container-remove"
    echo " - 🟢 jwdocker_container-inspect"
    echo
    echo " -----------------------------  image management"
    echo " - 🟢 jwdocker_images"
    echo " - 🔵 jwdocker_image-pull"
    echo " - 🔵 jwdocker_image-build"
    echo " - 🔴 jwdocker_image-rm"
    echo " - 🟢 jwdocker_image-history"
    echo
    echo " -----------------------------  volume management"
    echo " - 🟢 jwdocker_volumes"
    echo " - 🟢 jwdocker_volume-inspect"
    echo " - 🔵 jwdocker_volume-create"
    echo " - 🔴 jwdocker_volume-remove"
    echo " - 🔴 jwdocker_volume-prune"
    echo
    echo " -----------------------------  network management"
    echo " - 🟢 jwdocker_networks"
    echo " - 🟢 jwdocker_network-inspect"
    echo " - 🔵 jwdocker_network-create"
    echo " - 🔴 jwdocker_network-remove"
    echo " - ⚪ jwdocker_network-connect"
    echo " - ⚪ jwdocker_network-disconnect"
    echo " - 🔴 jwdocker_network-prune"
    echo
    echo " -----------------------------  resource monitoring"
    echo " - 🟢 jwdocker_monitor-stats"
    echo " - 🟢 jwdocker_monitor-top"
    echo " - 🟢 jwdocker_monitor-health"
    echo
    echo " -----------------------------  system cleanup & maintenance"
    echo " - 🟢 jwdocker_disk-usage"
    echo " - 🟢 jwdocker_system-info"
    echo " - 🔴 jwdocker_prune"
    echo " - 🔴 jwdocker_cleanup"
    echo " - 🟢 jwdocker_size"
    echo
    echo " -----------------------------  import/export utilities"
    echo " - 🔵 jwdocker_save"
    echo " - 🔵 jwdocker_load"
    echo " - 🔵 jwdocker_export"
    echo " - 🔵 jwdocker_import"
    echo
    echo " -----------------------------  quick utility functions"
    echo " - 🟢 jwdocker_search"
    echo " - 🔵 jwdocker_backup"
    echo " - ⚪ jwdocker_cp"
    echo " - 🔵 jwdocker_run"
    echo " - 🔵 jwdocker_tag"
    echo " - ⚪ jwdocker_push"
    echo " - 🟢 jwdocker_test-connectivity"
    echo
    echo " -----------------------------  troubleshooting tools"
    echo " - ⚪ jwdocker_exec"
    echo " - 🟢 jwdocker_logs"
    echo " - 🟢 jwdocker_port"
    echo
    echo " -----------------------------  development helpers"
    echo " - 🟢 jwdocker_test"
    echo " - 🟢 jwdocker_debug"
    echo " - ⚪ jwdocker_bench"
    echo
}


# ---------------------------------------------------------------------------------
# legacy: aliases
# ---------------------------------------------------------------------------------

alias jwdocker_findcontainerbyip="docker ps -q | xargs -n 1 docker inspect -f '{{.Id}} {{.Name}}  -  {{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' | grep"


# ---------------------------------------------------------------------------------
# ps
# ---------------------------------------------------------------------------------

alias jwdocker_ps="jwdocker_containers"
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
            echo "Usage: jwdocker_container-remove $CONTAINER force"
            return 1
        fi
        echo "Force removing running container: $CONTAINER"
        docker rm -f "$CONTAINER"
    else
        echo "Removing stopped container: $CONTAINER"
        docker rm "$CONTAINER"
    fi
}


jwdocker_container-inspect() {
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
        echo "Usage: jwdocker_image-pull <image[:tag]>"
        echo "Examples:"
        echo "  jwdocker_image-pull nginx"
        echo "  jwdocker_image-pull nginx:alpine"
        echo "  jwdocker_image-pull ubuntu:20.04"
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
        echo "Usage: jwdocker_image-build <tag> [dockerfile_path] [build_context]"
        echo "Examples:"
        echo "  jwdocker_image-build myapp:latest"
        echo "  jwdocker_image-build myapp:v1.0 ./Dockerfile ."
        echo "  jwdocker_image-build myapp:dev ./docker/Dockerfile.dev ./src"
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
            echo "Usage: jwdocker_image-rm $IMAGE force"
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
        echo "Usage: jwdocker_image-history <image> [--no-trunc]"
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
        echo "Usage: jwdocker_volume-create <volume_name> [driver] [options]"
        echo "Examples:"
        echo "  jwdocker_volume-create mydata"
        echo "  jwdocker_volume-create mydata local"
        echo "  jwdocker_volume-create mydata local --opt type=tmpfs"
        return 1
    fi

    local VOLUME_NAME=$1
    local DRIVER=${2:-local}
    shift                      # remove volume name
    [ $# -gt 0 ] && shift      # remove driver (only if one was supplied)
    # whatever is left in "$@" are the extra options — forward them as an
    # array so each token stays separate under both bash and zsh

    echo "Creating volume: $VOLUME_NAME"
    echo "Driver: $DRIVER"
    # Show the created volume info
    if [ $# -gt 0 ]; then
        echo "Options: $*"
        docker volume create --driver "$DRIVER" "$@" "$VOLUME_NAME"
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
            echo "Usage: jwdocker_volume-remove $VOLUME force"
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


jwdocker_network-inspect() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker network ls --format "- {{.Name}}"
        echo
        return 1
    fi

    local NETWORK=$1
    echo
    echo "---[ Network ]-----------------------------------------"
    docker inspect -f 'Id:         {{ .Id }}  [{{ .Name }}]' "$NETWORK"
    docker inspect -f 'Scope:      {{ .Scope }}' "$NETWORK"
    docker inspect -f 'Driver:     {{ .Driver }}' "$NETWORK"
    docker inspect -f '{{ range $item := .IPAM.Config }}{{ range $key, $value := $item }}{{printf "%s\t\t%s\n" $key $value}}{{ end }}{{ end }}' "$NETWORK"
    echo "---[ Containers ]--------------------------------------"
    docker network inspect -f '{{ range $key, $value := .Containers }}{{printf "%s: [%s]  %s\n" $key .IPv4Address .Name}}{{ end }}' "$NETWORK"
}


jwdocker_network-create() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdocker_network-create <network_name> [driver] [options]"
        echo "Examples:"
        echo "  jwdocker_network-create mynetwork"
        echo "  jwdocker_network-create mynetwork bridge"
        echo "  jwdocker_network-create mynetwork bridge --subnet=172.20.0.0/16"
        echo "  jwdocker_network-create mynetwork overlay --attachable"
        return 1
    fi

    local NETWORK_NAME=$1
    local DRIVER=${2:-bridge}
    shift                      # remove network name
    [ $# -gt 0 ] && shift      # remove driver (only if one was supplied)
    # whatever is left in "$@" are the extra options — forward them as an
    # array so each token stays separate under both bash and zsh

    echo "Creating network: $NETWORK_NAME"
    echo "Driver: $DRIVER"
    # Show the created network info
    if [ $# -gt 0 ]; then
        echo "Options: $*"
        docker network create --driver "$DRIVER" "$@" "$NETWORK_NAME"
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
    # (one container name per line, so it iterates safely under bash and zsh)
    local using_containers
    using_containers=$(docker network inspect "$NETWORK" --format '{{ range $key, $value := .Containers }}{{ .Name }}{{ "\n" }}{{ end }}' 2>/dev/null)

    if [ -n "$using_containers" ]; then
        if [ "$FORCE" != "force" ] && [ "$FORCE" != "-f" ]; then
            echo "Error: Network '$NETWORK' is being used by containers:"
            while IFS= read -r container; do
                [ -n "$container" ] && echo " - $container"
            done <<< "$using_containers"
            echo "Disconnect containers first or use 'force' flag."
            echo "Usage: jwdocker_network-remove $NETWORK force"
            return 1
        fi
        echo "Force removing network used by containers: $NETWORK"
        # 'docker network rm' won't detach active endpoints; disconnect them first.
        while IFS= read -r container; do
            [ -n "$container" ] || continue
            echo "  Disconnecting: $container"
            docker network disconnect -f "$NETWORK" "$container"
        done <<< "$using_containers"
        docker network rm "$NETWORK" || echo "Failed to remove network (may still be in use)"
    else
        echo "Removing network: $NETWORK"
        docker network rm "$NETWORK"
    fi
}


jwdocker_network-connect() {
    if [ $# -lt 2 ]; then
        echo "Usage: jwdocker_network-connect <network> <container> [options]"
        echo "Examples:"
        echo "  jwdocker_network-connect mynetwork mycontainer"
        echo "  jwdocker_network-connect mynetwork mycontainer --ip=172.20.0.10"
        echo "  jwdocker_network-connect mynetwork mycontainer --alias=web"
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
    # whatever is left in "$@" are the extra options — forward them as an
    # array so each token stays separate under both bash and zsh

    echo "Connecting container '$CONTAINER' to network '$NETWORK'"
    # Show the connection info
    if [ $# -gt 0 ]; then
        echo "Options: $*"
        docker network connect "$@" "$NETWORK" "$CONTAINER"
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
        echo "Usage: jwdocker_network-disconnect <network> <container> [force]"
        echo "Examples:"
        echo "  jwdocker_network-disconnect mynetwork mycontainer"
        echo "  jwdocker_network-disconnect mynetwork mycontainer force"
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
        # NB: test "unhealthy" before "healthy" — the latter is a substring of the former.
        if echo "$container_status" | grep -q "unhealthy"; then
            echo -e "$name\t$(jwpaintfgRed "$container_status")"
        elif echo "$container_status" | grep -q "healthy"; then
            echo -e "$name\t$(jwpaintfgGreen "$container_status")"
        elif echo "$container_status" | grep -q "starting"; then
            echo -e "$name\t$(jwpaintfgBrown "$container_status")"
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
    docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}"
    echo
}


jwdocker_prune() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdocker_prune [containers|images|volumes|networks|system|all]"
        echo "Examples:"
        echo "  jwdocker_prune containers  # Remove stopped containers"
        echo "  jwdocker_prune images      # Remove unused images"
        echo "  jwdocker_prune volumes     # Remove unused volumes"
        echo "  jwdocker_prune networks    # Remove unused networks"
        echo "  jwdocker_prune system      # Remove containers, networks, images (not volumes)"
        echo "  jwdocker_prune all         # Remove everything unused (including volumes)"
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
            jwdocker_volume-prune
            ;;
        networks)
            jwdocker_network-prune
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
            jwdocker_prune containers
            ;;
        b|B)
            jwdocker_prune images
            ;;
        c|C)
            jwdocker_prune volumes
            ;;
        d|D)
            jwdocker_prune networks
            ;;
        e|E)
            jwdocker_prune system
            ;;
        f|F)
            jwdocker_prune all
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
        echo "Usage: jwdocker_size [containers|images|volumes|all]"
        echo "Examples:"
        echo "  jwdocker_size containers  # Show container sizes"
        echo "  jwdocker_size images      # Show image sizes"
        echo "  jwdocker_size volumes     # Show volume sizes"
        echo "  jwdocker_size all         # Show everything"
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
            jwdocker_size containers
            jwdocker_size images
            jwdocker_size volumes
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
        echo "Usage: jwdocker_save <image> [output_file]"
        echo "Examples:"
        echo "  jwdocker_save nginx                    # Saves to nginx.tar"
        echo "  jwdocker_save nginx:alpine             # Saves to nginx_alpine.tar"
        echo "  jwdocker_save nginx /tmp/nginx.tar     # Saves to specific file"
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
        echo "Usage: jwdocker_load <tar_file>"
        echo "Examples:"
        echo "  jwdocker_load nginx.tar"
        echo "  jwdocker_load /tmp/myimage.tar"
        echo
        echo "Available tar files in current directory:"
        local tars=""
        tars=$(find . -maxdepth 1 -name '*.tar' 2>/dev/null | sort)
        if [ -n "$tars" ]; then printf '%s\n' "$tars"; else echo "  (no .tar files found)"; fi
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
        echo "Usage: jwdocker_export <container> [output_file]"
        echo "Examples:"
        echo "  jwdocker_export mycontainer                    # Exports to mycontainer.tar"
        echo "  jwdocker_export mycontainer /tmp/backup.tar    # Exports to specific file"
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
        echo "Usage: jwdocker_import <tar_file> [repository[:tag]]"
        echo "Examples:"
        echo "  jwdocker_import container.tar                    # Imports as <none>:<none>"
        echo "  jwdocker_import container.tar myimage:latest     # Imports with specific name"
        echo
        echo "Available tar files in current directory:"
        local tars=""
        tars=$(find . -maxdepth 1 -name '*.tar' 2>/dev/null | sort)
        if [ -n "$tars" ]; then printf '%s\n' "$tars"; else echo "  (no .tar files found)"; fi
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
        echo "Usage: jwdocker_search <search_term> [limit]"
        echo "Examples:"
        echo "  jwdocker_search nginx"
        echo "  jwdocker_search nginx 10"
        echo "  jwdocker_search ubuntu/nginx"
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
        echo "Usage: jwdocker_backup <container> [backup_dir]"
        echo "Examples:"
        echo "  jwdocker_backup mycontainer"
        echo "  jwdocker_backup mycontainer /backups"
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
        echo "Usage: jwdocker_cp <source> <destination>"
        echo "Examples:"
        echo "  jwdocker_cp mycontainer:/app/config.txt ./config.txt"
        echo "  jwdocker_cp ./data.json mycontainer:/tmp/data.json"
        echo "  jwdocker_cp mycontainer:/logs/ ./container-logs/"
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
        echo "Usage: jwdocker_run [options] <image> [command]"
        echo "       (arguments are passed straight to 'docker run' in native order)"
        echo "Examples:"
        echo "  jwdocker_run nginx"
        echo "  jwdocker_run -p 8080:80 nginx"
        echo "  jwdocker_run -it --rm ubuntu:20.04 bash"
        echo "  jwdocker_run -e POSTGRES_PASSWORD=secret postgres:13"
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

    echo "Running container..."
    # Forward arguments verbatim to 'docker run' in Docker's native order:
    #   jwdocker_run [OPTIONS] IMAGE [COMMAND...]
    # A lone image is run detached by default.
    if [ $# -eq 1 ]; then
        echo "Using default options: -d (detached)"
        docker run -d "$1"
    else
        docker run "$@"
    fi && {
        # Show the new container if it was created
        echo
        echo "---[ New Container ]--------------------------------"
        docker ps -l --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    }
}


jwdocker_tag() {
    if [ $# -lt 2 ]; then
        echo "Usage: jwdocker_tag <source_image> <target_image>"
        echo "Examples:"
        echo "  jwdocker_tag nginx:latest myregistry.com/nginx:v1.0"
        echo "  jwdocker_tag myapp:latest myapp:production"
        echo "  jwdocker_tag ubuntu:20.04 ubuntu:focal"
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
        echo "Usage: jwdocker_push <image>"
        echo "Examples:"
        echo "  jwdocker_push myregistry.com/myapp:latest"
        echo "  jwdocker_push username/myimage:v1.0"
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


jwdocker_test-connectivity() {
    if [ $# -lt 2 ]; then
        echo "Usage: jwdocker_test-connectivity <source_container> <target_container> [port]"
        echo "Examples:"
        echo "  jwdocker_test-connectivity web database"
        echo "  jwdocker_test-connectivity web api 8080"
        echo "  jwdocker_test-connectivity frontend backend 3000"
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
    local target_ips=()
    
    while IFS=: read -r source_network _source_ip; do
        if [ -n "$source_network" ]; then
            while IFS=: read -r target_network target_ip; do
                if [ -n "$target_network" ] && [ "$source_network" = "$target_network" ]; then
                    echo "  ✅ $source_network (target IP: $target_ip)"
                    shared_networks="$shared_networks $source_network"
                    target_ips+=("$target_ip")
                fi
            done <<< "$target_networks"
        fi
    done <<< "$source_networks"
    
    if [ -z "$shared_networks" ]; then
        echo "  ❌ No shared networks found!"
        echo
        echo "💡 To enable connectivity, connect both containers to the same network:"
        echo "   jwdocker_network-connect <network_name> $SOURCE_CONTAINER"
        echo "   jwdocker_network-connect <network_name> $TARGET_CONTAINER"
        return 1
    fi
    echo
    
    # Test connectivity
    echo "---[ Connectivity Tests ]---------------------------"
    
    # Test ping connectivity to each shared network IP
    for target_ip in "${target_ips[@]}"; do
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
        for target_ip in "${target_ips[@]}"; do
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


# ---------------------------------------------------------------------------------
# development helpers (test / debug / benchmark)
# ---------------------------------------------------------------------------------

jwdocker_test() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdocker_test <container> <test_type> [options]"
        echo "Test types:"
        echo "  health      - Check container health, status, and restart count"
        echo "  logs        - Analyze logs for errors and warnings"
        echo "  resources   - Check resource usage and constraints"
        echo "  config      - Validate configuration (env vars, volumes, ports)"
        echo "  deps        - Test dependencies and external connectivity"
        echo "  http        - Test HTTP endpoints (for web services)"
        echo "  perf        - Basic performance metrics"
        echo "  all         - Run all applicable tests"
        echo
        echo "Examples:"
        echo "  jwdocker_test myapp health"
        echo "  jwdocker_test myapp logs"
        echo "  jwdocker_test myapp http 8080"
        echo "  jwdocker_test myapp all"
        echo
        echo "Available containers:"
        docker ps -a --format "- {{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    local TEST_TYPE=$2
    local OPTION=$3

    # Check if container exists
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        echo "Error: Container '$CONTAINER' not found."
        return 1
    fi

    echo "🧪 Testing container: $CONTAINER"
    echo "=================================================="
    echo

    case $TEST_TYPE in
        health)
            __jwdocker_test_health__ "$CONTAINER"
            ;;
        logs)
            __jwdocker_test_logs__ "$CONTAINER" "$OPTION"
            ;;
        resources)
            __jwdocker_test_resources__ "$CONTAINER"
            ;;
        config)
            __jwdocker_test_config__ "$CONTAINER"
            ;;
        deps)
            __jwdocker_test_deps__ "$CONTAINER"
            ;;
        http)
            __jwdocker_test_http__ "$CONTAINER" "$OPTION"
            ;;
        perf)
            __jwdocker_test_perf__ "$CONTAINER"
            ;;
        all)
            __jwdocker_test_health__ "$CONTAINER"
            __jwdocker_test_logs__ "$CONTAINER"
            __jwdocker_test_resources__ "$CONTAINER"
            __jwdocker_test_config__ "$CONTAINER"
            __jwdocker_test_deps__ "$CONTAINER"
            __jwdocker_test_perf__ "$CONTAINER"
            ;;
        *)
            echo "Error: Unknown test type '$TEST_TYPE'"
            echo "Valid types: health, logs, resources, config, deps, http, perf, all"
            return 1
            ;;
    esac
}

__jwdocker_test_health__() {
    local CONTAINER=$1
    echo "---[ Health Check ]--------------------------------"
    
    # Container status
    local container_status
    container_status=$(docker inspect --format='{{.State.Status}}' "$CONTAINER")
    echo -n "Status: "
    if [ "$container_status" = "running" ]; then
        echo "✅ $container_status"
    else
        echo "❌ $container_status"
    fi
    
    # Exit code
    local exit_code
    exit_code=$(docker inspect --format='{{.State.ExitCode}}' "$CONTAINER")
    echo -n "Exit Code: "
    if [ "$exit_code" = "0" ]; then
        echo "✅ $exit_code"
    else
        echo "❌ $exit_code"
    fi
    
    # Restart count
    local restart_count
    restart_count=$(docker inspect --format='{{.RestartCount}}' "$CONTAINER")
    echo -n "Restart Count: "
    if [ "$restart_count" = "0" ]; then
        echo "✅ $restart_count"
    else
        echo "⚠️  $restart_count (container has been restarted)"
    fi
    
    # Health status (if healthcheck is configured)
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null)
    if [ -n "$health_status" ] && [ "$health_status" != "<no value>" ]; then
        echo -n "Health Status: "
        case $health_status in
            healthy)
                echo "✅ $health_status"
                ;;
            unhealthy)
                echo "❌ $health_status"
                ;;
            starting)
                echo "⚠️  $health_status"
                ;;
            *)
                echo "❓ $health_status"
                ;;
        esac
    fi
    
    # Uptime
    local started_at
    started_at=$(docker inspect --format='{{.State.StartedAt}}' "$CONTAINER")
    if [ "$started_at" != "0001-01-01T00:00:00Z" ]; then
        echo "Started: $started_at"
    fi
    
    echo
}

__jwdocker_test_logs__() {
    local CONTAINER=$1
    local LINES=${2:-100}
    
    echo "---[ Log Analysis ]--------------------------------"
    echo "Analyzing last $LINES log lines..."
    
    # Get logs
    local logs
    logs=$(docker logs --tail "$LINES" "$CONTAINER" 2>&1)
    
    if [ -z "$logs" ]; then
        echo "⚠️  No logs found"
        echo
        return
    fi
    
    # Count different log levels
    local errors
    local warnings
    local total_lines
    
    errors=$(echo "$logs" | grep -ci "error\|exception\|fatal\|panic" || true)
    warnings=$(echo "$logs" | grep -ci "warn\|warning" || true)
    total_lines=$(echo "$logs" | wc -l)
    
    echo "Total log lines: $total_lines"
    echo -n "Errors: "
    if [ "$errors" -gt 0 ]; then
        echo "❌ $errors found"
    else
        echo "✅ $errors"
    fi
    
    echo -n "Warnings: "
    if [ "$warnings" -gt 0 ]; then
        echo "⚠️  $warnings found"
    else
        echo "✅ $warnings"
    fi
    
    # Show recent errors if any
    if [ "$errors" -gt 0 ]; then
        echo
        echo "Recent errors:"
        echo "$logs" | grep -i "error\|exception\|fatal\|panic" | sed 's/^/  /'
    fi
    
    echo
}

__jwdocker_test_resources__() {
    local CONTAINER=$1
    
    echo "---[ Resource Usage ]------------------------------"
    
    # Get resource stats
    local stats
    stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}" "$CONTAINER" 2>/dev/null)
    
    if [ -z "$stats" ]; then
        echo "❌ Unable to get resource stats (container may not be running)"
        echo
        return
    fi
    
    IFS=',' read -r cpu_perc mem_usage mem_perc net_io block_io <<< "$stats"
    
    echo "CPU Usage: $cpu_perc"
    echo "Memory Usage: $mem_usage ($mem_perc)"
    echo "Network I/O: $net_io"
    echo "Block I/O: $block_io"
    
    # Check for resource constraints
    local cpu_num
    cpu_num=$(echo "$cpu_perc" | sed 's/%//' | cut -d. -f1)
    if [ "$cpu_num" -gt 80 ] 2>/dev/null; then
        echo "⚠️  High CPU usage detected"
    fi
    
    local mem_num
    mem_num=$(echo "$mem_perc" | sed 's/%//' | cut -d. -f1)
    if [ "$mem_num" -gt 80 ] 2>/dev/null; then
        echo "⚠️  High memory usage detected"
    fi
    
    echo
}

__jwdocker_test_config__() {
    local CONTAINER=$1

    echo "---[ Configuration Validation ]--------------------"

    # NB: `docker inspect --format` appends its own trailing newline after the
    # template's, so `... | wc -l` over-counts by one. Capture each list once,
    # drop the trailing blank with `grep .`, and count what is actually shown.

    # Environment variables — list them, don't just count
    local envs
    envs=$(docker inspect --format='{{range .Config.Env}}{{printf "%s\n" .}}{{end}}' "$CONTAINER" | grep .)
    echo "Environment variables: $(printf '%s\n' "$envs" | grep -c .) configured"
    [ -n "$envs" ] && printf '%s\n' "$envs" | sed 's/^/  /'

    # Volumes
    local volumes
    volumes=$(docker inspect --format='{{range .Mounts}}{{printf "%s -> %s (%s)\n" .Source .Destination .Type}}{{end}}' "$CONTAINER" | grep .)
    echo -n "Volumes: "
    if [ -n "$volumes" ]; then
        echo "✅ $(printf '%s\n' "$volumes" | grep -c .) mounted"
        printf '%s\n' "$volumes" | sed 's/^/  /'
    else
        echo "⚠️  No volumes mounted"
    fi

    # Ports
    local ports
    ports=$(docker inspect --format='{{range $key, $value := .NetworkSettings.Ports}}{{printf "%s -> %s\n" $key $value}}{{end}}' "$CONTAINER" | grep .)
    echo -n "Exposed ports: "
    if [ -n "$ports" ]; then
        echo "✅ $(printf '%s\n' "$ports" | grep -c .) configured"
        printf '%s\n' "$ports" | sed 's/^/  /'
    else
        echo "⚠️  No ports exposed"
    fi

    echo
}

__jwdocker_test_deps__() {
    local CONTAINER=$1
    
    echo "---[ Dependency Testing ]--------------------------"
    
    # Check if container is running
    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        echo "❌ Container is not running - cannot test dependencies"
        echo
        return
    fi
    
    # Test basic network connectivity
    echo -n "Internet connectivity: "
    if docker exec "$CONTAINER" ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo "✅ Available"
    else
        echo "❌ Failed"
    fi
    
    # Test DNS resolution
    echo -n "DNS resolution: "
    if docker exec "$CONTAINER" nslookup google.com >/dev/null 2>&1; then
        echo "✅ Working"
    else
        echo "❌ Failed"
    fi
    
    # Check for common dependency tools
    echo "Available tools:"
    for tool in curl wget nc telnet ping nslookup; do
        if docker exec "$CONTAINER" sh -c "command -v $tool >/dev/null 2>&1"; then
            echo "  ✅ $tool"
        else
            echo "  ❌ $tool"
        fi
    done
    
    echo
}

__jwdocker_test_http__() {
    local CONTAINER=$1
    local PORT=${2:-80}
    
    echo "---[ HTTP Testing ]--------------------------------"
    
    # Check if container is running
    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        echo "❌ Container is not running - cannot test HTTP"
        echo
        return
    fi
    
    # Get container IP
    local container_ip
    container_ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER" | head -1)
    
    if [ -z "$container_ip" ]; then
        echo "❌ Could not determine container IP"
        echo
        return
    fi
    
    echo "Testing HTTP on $container_ip:$PORT"
    
    # Test if port is listening
    echo -n "Port $PORT listening: "
    if docker exec "$CONTAINER" sh -c "command -v nc >/dev/null 2>&1"; then
        if docker exec "$CONTAINER" nc -z localhost "$PORT" 2>/dev/null; then
            echo "✅ Yes"
        else
            echo "❌ No"
            echo
            return
        fi
    elif docker exec "$CONTAINER" sh -c "command -v curl >/dev/null 2>&1"; then
        # No nc — fall back to curl (connect-only probe; a service that accepts
        # the connection and speaks HTTP counts as listening).
        if docker exec "$CONTAINER" curl -s -o /dev/null --connect-timeout 5 "http://localhost:$PORT" 2>/dev/null; then
            echo "✅ Yes (via curl)"
        else
            echo "❌ No (or not speaking HTTP)"
        fi
    else
        echo "⚠️  Cannot test (no nc or curl available)"
    fi
    
    # Test HTTP response if curl is available
    if docker exec "$CONTAINER" sh -c "command -v curl >/dev/null 2>&1"; then
        echo -n "HTTP response: "
        local http_code
        # curl's -w already prints "000" when no response arrives; an `|| echo`
        # fallback would DOUBLE it ("000000"), so default only when truly empty.
        http_code=$(docker exec "$CONTAINER" curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "http://localhost:$PORT" 2>/dev/null)
        [ -z "$http_code" ] && http_code="000"

        case $http_code in
            200|201|202|204)
                echo "✅ $http_code (Success)"
                ;;
            3*)
                echo "⚠️  $http_code (Redirect)"
                ;;
            4*)
                echo "❌ $http_code (Client Error)"
                ;;
            5*)
                echo "❌ $http_code (Server Error)"
                ;;
            000)
                echo "❌ No response"
                ;;
            *)
                echo "❓ $http_code"
                ;;
        esac
    else
        echo "⚠️  Cannot test HTTP response (curl not available)"
    fi
    
    echo
}

__jwdocker_test_perf__() {
    local CONTAINER=$1
    
    echo "---[ Performance Metrics ]-------------------------"
    
    # Check if container is running
    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        echo "❌ Container is not running - cannot get performance metrics"
        echo
        return
    fi
    
    # Get detailed stats
    local stats
    stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}},{{.PIDs}}" "$CONTAINER" 2>/dev/null)
    
    if [ -z "$stats" ]; then
        echo "❌ Unable to get performance stats"
        echo
        return
    fi
    
    IFS=',' read -r cpu_perc mem_usage mem_perc net_io block_io pids <<< "$stats"
    
    echo "Current Performance:"
    echo "  CPU: $cpu_perc"
    echo "  Memory: $mem_usage ($mem_perc)"
    echo "  Network I/O: $net_io"
    echo "  Block I/O: $block_io"
    echo "  PIDs: $pids"
    
    # Performance assessment
    echo
    echo "Performance Assessment:"
    
    local cpu_num
    cpu_num=$(echo "$cpu_perc" | sed 's/%//' | cut -d. -f1 2>/dev/null || echo "0")
    if [ "$cpu_num" -lt 50 ] 2>/dev/null; then
        echo "  CPU: ✅ Normal ($cpu_perc)"
    elif [ "$cpu_num" -lt 80 ] 2>/dev/null; then
        echo "  CPU: ⚠️  Moderate ($cpu_perc)"
    else
        echo "  CPU: ❌ High ($cpu_perc)"
    fi
    
    local mem_num
    mem_num=$(echo "$mem_perc" | sed 's/%//' | cut -d. -f1 2>/dev/null || echo "0")
    if [ "$mem_num" -lt 70 ] 2>/dev/null; then
        echo "  Memory: ✅ Normal ($mem_perc)"
    elif [ "$mem_num" -lt 90 ] 2>/dev/null; then
        echo "  Memory: ⚠️  High ($mem_perc)"
    else
        echo "  Memory: ❌ Critical ($mem_perc)"
    fi
    
    echo
}


jwdocker_debug() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdocker_debug <container> [focus_area]"
        echo "Focus areas:"
        echo "  startup     - Debug container startup issues"
        echo "  network     - Debug network connectivity issues"
        echo "  filesystem  - Debug filesystem and volume issues"
        echo "  process     - Debug process and application issues"
        echo "  all         - Run all debug checks"
        echo
        echo "Examples:"
        echo "  jwdocker_debug myapp"
        echo "  jwdocker_debug myapp startup"
        echo "  jwdocker_debug myapp network"
        echo
        echo "Available containers:"
        docker ps -a --format "- {{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    local FOCUS=${2:-all}

    # Check if container exists
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        echo "Error: Container '$CONTAINER' not found."
        return 1
    fi

    echo "🐛 Debugging container: $CONTAINER"
    echo "=================================================="
    echo

    case $FOCUS in
        startup|all)
            __jwdocker_debug_startup__ "$CONTAINER"
            ;;
    esac

    case $FOCUS in
        network|all)
            __jwdocker_debug_network__ "$CONTAINER"
            ;;
    esac

    case $FOCUS in
        filesystem|all)
            __jwdocker_debug_filesystem__ "$CONTAINER"
            ;;
    esac

    case $FOCUS in
        process|all)
            __jwdocker_debug_process__ "$CONTAINER"
            ;;
    esac
}

__jwdocker_debug_startup__() {
    local CONTAINER=$1
    
    echo "---[ Startup Debug ]-------------------------------"
    
    # Container state
    local container_status
    container_status=$(docker inspect --format='{{.State.Status}}' "$CONTAINER")
    echo "Current Status: $container_status"
    
    # Exit code and error
    local exit_code
    local error
    exit_code=$(docker inspect --format='{{.State.ExitCode}}' "$CONTAINER")
    error=$(docker inspect --format='{{.State.Error}}' "$CONTAINER")
    
    if [ "$exit_code" != "0" ]; then
        echo "❌ Exit Code: $exit_code"
        if [ -n "$error" ] && [ "$error" != "<no value>" ]; then
            echo "❌ Error: $error"
        fi
    fi
    
    # Recent logs for startup issues
    echo
    echo "Recent startup logs:"
    docker logs --tail 20 "$CONTAINER" 2>&1 | sed 's/^/  /'
    
    # Check if image exists
    local image
    image=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER")
    echo
    echo "Image: $image"
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
        echo "✅ Image exists locally"
    else
        echo "❌ Image not found locally"
    fi
    
    echo
}

__jwdocker_debug_network__() {
    local CONTAINER=$1
    
    echo "---[ Network Debug ]-------------------------------"
    
    # Network settings
    echo "Networks:"
    docker inspect --format='{{range $key, $value := .NetworkSettings.Networks}}{{printf "  %s: %s\n" $key .IPAddress}}{{end}}' "$CONTAINER"
    
    # Port mappings
    echo
    echo "Port mappings:"
    docker inspect --format='{{range $key, $value := .NetworkSettings.Ports}}{{printf "  %s -> %s\n" $key $value}}{{end}}' "$CONTAINER"
    
    # Test basic connectivity if running
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        echo
        echo "Connectivity tests:"
        echo -n "  Internet: "
        if docker exec "$CONTAINER" ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            echo "✅"
        else
            echo "❌"
        fi
        
        echo -n "  DNS: "
        if docker exec "$CONTAINER" nslookup google.com >/dev/null 2>&1; then
            echo "✅"
        else
            echo "❌"
        fi
    fi
    
    echo
}

__jwdocker_debug_filesystem__() {
    local CONTAINER=$1
    
    echo "---[ Filesystem Debug ]----------------------------"
    
    # Volume mounts
    echo "Volume mounts:"
    docker inspect --format='{{range .Mounts}}{{printf "  %s -> %s (%s, %s)\n" .Source .Destination .Type .Mode}}{{end}}' "$CONTAINER"
    
    # Check if running to test filesystem
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        echo
        echo "Filesystem tests:"
        
        # Check working directory
        local workdir
        workdir=$(docker inspect --format='{{.Config.WorkingDir}}' "$CONTAINER")
        if [ -n "$workdir" ] && [ "$workdir" != "/" ]; then
            echo -n "  Working directory ($workdir): "
            if docker exec "$CONTAINER" test -d "$workdir"; then
                echo "✅ Exists"
            else
                echo "❌ Missing"
            fi
        fi
        
        # Check disk space
        echo "  Disk usage:"
        docker exec "$CONTAINER" df -h 2>/dev/null | sed 's/^/    /' || echo "    ❌ Cannot check disk usage"
    fi
    
    echo
}

__jwdocker_debug_process__() {
    local CONTAINER=$1
    
    echo "---[ Process Debug ]-------------------------------"
    
    # Check if running
    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        echo "❌ Container is not running - cannot debug processes"
        echo
        return
    fi
    
    # Process list
    echo "Running processes:"
    docker exec "$CONTAINER" ps aux 2>/dev/null | sed 's/^/  /' || echo "  ❌ Cannot list processes"
    
    # Check main process
    echo
    local pid1_cmd
    pid1_cmd=$(docker exec "$CONTAINER" ps -p 1 -o comm= 2>/dev/null || echo "unknown")
    echo "Main process (PID 1): $pid1_cmd"
    
    # Resource usage
    echo
    echo "Resource usage:"
    docker exec "$CONTAINER" top -bn1 | head -5 | sed 's/^/  /' 2>/dev/null || echo "  ❌ Cannot get resource usage"
    
    echo
}


jwdocker_bench() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdocker_bench <container> [test_type]"
        echo "Test types:"
        echo "  cpu         - CPU performance test"
        echo "  memory      - Memory performance test"
        echo "  disk        - Disk I/O performance test"
        echo "  network     - Network performance test"
        echo "  all         - Run all benchmarks"
        echo
        echo "Examples:"
        echo "  jwdocker_bench myapp cpu"
        echo "  jwdocker_bench myapp all"
        echo
        echo "Available running containers:"
        docker ps --format "- {{.Names}}"
        echo
        return 1
    fi

    local CONTAINER=$1
    local TEST_TYPE=${2:-all}

    # Check if container is running
    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        echo "Error: Container '$CONTAINER' is not running."
        return 1
    fi

    echo "⚡ Benchmarking container: $CONTAINER"
    echo "=================================================="
    echo

    case $TEST_TYPE in
        cpu|all)
            __jwdocker_bench_cpu__ "$CONTAINER"
            ;;
    esac

    case $TEST_TYPE in
        memory|all)
            __jwdocker_bench_memory__ "$CONTAINER"
            ;;
    esac

    case $TEST_TYPE in
        disk|all)
            __jwdocker_bench_disk__ "$CONTAINER"
            ;;
    esac

    case $TEST_TYPE in
        network|all)
            __jwdocker_bench_network__ "$CONTAINER"
            ;;
    esac
}

__jwdocker_bench_cpu__() {
    local CONTAINER=$1
    
    echo "---[ CPU Benchmark ]-------------------------------"
    
    # Simple CPU test using dd and time
    echo "Running CPU stress test (10 seconds)..."
    local start_time
    local end_time
    local duration
    
    start_time=$(date +%s)
    docker exec "$CONTAINER" sh -c 'timeout 10 yes > /dev/null 2>&1 || true' >/dev/null 2>&1
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo "CPU test completed in ${duration}s"
    
    # Get CPU stats during and after test
    echo "CPU usage after test:"
    docker stats --no-stream --format "  CPU: {{.CPUPerc}}" "$CONTAINER"
    
    echo
}

__jwdocker_bench_memory__() {
    local CONTAINER=$1
    
    echo "---[ Memory Benchmark ]----------------------------"
    
    # Memory allocation test
    echo "Testing memory allocation..."
    
    # Get current memory usage
    local mem_before
    mem_before=$(docker stats --no-stream --format "{{.MemUsage}}" "$CONTAINER")
    echo "Memory before test: $mem_before"
    
    # Simple memory test
    docker exec "$CONTAINER" sh -c 'dd if=/dev/zero of=/tmp/memtest bs=1M count=100 2>/dev/null && rm -f /tmp/memtest' >/dev/null 2>&1 || echo "Memory test completed"
    
    # Get memory usage after
    local mem_after
    mem_after=$(docker stats --no-stream --format "{{.MemUsage}}" "$CONTAINER")
    echo "Memory after test: $mem_after"
    
    echo
}

__jwdocker_bench_disk__() {
    local CONTAINER=$1
    
    echo "---[ Disk I/O Benchmark ]--------------------------"
    
    # Write test
    echo "Testing disk write performance..."
    local write_result
    write_result=$(docker exec "$CONTAINER" sh -c 'dd if=/dev/zero of=/tmp/disktest bs=1M count=100 2>&1 | grep -o "[0-9.]* MB/s" | tail -1' || echo "N/A")
    echo "Write speed: $write_result"
    
    # Read test
    echo "Testing disk read performance..."
    local read_result
    read_result=$(docker exec "$CONTAINER" sh -c 'dd if=/tmp/disktest of=/dev/null bs=1M 2>&1 | grep -o "[0-9.]* MB/s" | tail -1' || echo "N/A")
    echo "Read speed: $read_result"
    
    # Cleanup
    docker exec "$CONTAINER" rm -f /tmp/disktest 2>/dev/null || true
    
    echo
}

__jwdocker_bench_network__() {
    local CONTAINER=$1
    
    echo "---[ Network Benchmark ]---------------------------"
    
    # Test network connectivity and basic performance
    echo "Testing network connectivity..."
    
    # Ping test
    echo -n "Ping to 8.8.8.8: "
    local ping_result
    ping_result=$(docker exec "$CONTAINER" ping -c 5 8.8.8.8 2>/dev/null | grep 'avg' | cut -d'/' -f5 || echo "failed")
    if [ "$ping_result" != "failed" ]; then
        echo "${ping_result}ms average"
    else
        echo "❌ Failed"
    fi
    
    # DNS resolution test
    echo -n "DNS resolution: "
    local dns_start
    local dns_end
    dns_start=$(date +%s%N)
    if docker exec "$CONTAINER" nslookup google.com >/dev/null 2>&1; then
        dns_end=$(date +%s%N)
        local dns_time
        dns_time=$(( (dns_end - dns_start) / 1000000 ))
        echo "✅ ${dns_time}ms"
    else
        echo "❌ Failed"
    fi
    
    # Download test if curl/wget available
    if docker exec "$CONTAINER" sh -c "command -v curl >/dev/null 2>&1"; then
        echo "Testing download speed..."
        docker exec "$CONTAINER" curl -s -w "Download speed: %{speed_download} bytes/sec\n" -o /dev/null http://httpbin.org/bytes/1048576 2>/dev/null || echo "Download test failed"
    fi
    
    echo
}

