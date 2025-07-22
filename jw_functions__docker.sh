# shellcheck shell=bash
alias jwdlf="docker logs -f"
alias jwdockerfindcontainerbyip="docker ps -q | xargs -n 1 docker inspect -f '{{.Id}} {{.Name}}  -  {{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' | grep"
alias jwdockerps="jwdockerpsup"


# ---------------------------------------------------------------------------------
# ps 
# ---------------------------------------------------------------------------------

jwdockerpsup() {
    if [ $# -eq 0 ]; then
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    else
        # Filter running containers by name
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | head -1
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -i "$1"
    fi
}


jwdockerpsall() {
    if [ $# -eq 0 ]; then
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    else
        # Filter all containers by name
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | head -1
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -i "$1"
    fi
}


jwdockerpsdown() {
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
# resource monitoring
# ---------------------------------------------------------------------------------

jwdockerstats() {
    if [ $# -eq 0 ]; then
        # Show stats for all running containers with clean formatting
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    else
        # Show stats for specific container(s)
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" "$@"
    fi
}


jwdockertop() {
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


jwdockerhealth() {
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
# troubleshooting tools
# ---------------------------------------------------------------------------------

jwdockerexec() {
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


jwdockerlogs() {
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


jwdockerport() {
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
# container lifecycle management
# ---------------------------------------------------------------------------------

jwdockerstart() {
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


jwdockerstop() {
    if [ $# -eq 0 ]; then
        local running_containers
        running_containers=$(docker ps --filter status=running --format "{{.Names}}")
        
        if [ -z "$running_containers" ]; then
            echo "No running containers found."
            return 0
        fi
        
        echo "Currently running:"
        echo "$running_containers" | sed 's/^/ - /'
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


jwdockerrestart() {
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


jwdockerremove() {
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

jwdockerimages() {
    if [ $# -eq 0 ]; then
        # Show all images with clean formatting
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}"
    else
        # Filter images by repository name
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | head -1
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | grep -i "$1"
    fi
}


jwdockerpull() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockerpull <image[:tag]>"
        echo "Examples:"
        echo "  jwdockerpull nginx"
        echo "  jwdockerpull nginx:alpine"
        echo "  jwdockerpull ubuntu:20.04"
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


jwdockerbuild() {
    if [ $# -eq 0 ]; then
        echo "Usage: jwdockerbuild <tag> [dockerfile_path] [build_context]"
        echo "Examples:"
        echo "  jwdockerbuild myapp:latest"
        echo "  jwdockerbuild myapp:v1.0 ./Dockerfile ."
        echo "  jwdockerbuild myapp:dev ./docker/Dockerfile.dev ./src"
        return 1
    fi

    local TAG=$1
    local DOCKERFILE=${2:-Dockerfile}
    local CONTEXT=${3:-.}
    
    echo "Building image: $TAG"
    echo "Dockerfile: $DOCKERFILE"
    echo "Build context: $CONTEXT"
    echo
    
    docker build -t "$TAG" -f "$DOCKERFILE" "$CONTEXT"
    
    # Show the built image info
    if [ $? -eq 0 ]; then
        echo
        echo "---[ Built Image Info ]----------------------------"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | head -1
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | grep "$(echo "$TAG" | cut -d: -f1)"
    fi
}


jwdockerrmi() {
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
            echo "$using_containers" | sed 's/^/ - /'
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


jwdockerimagehistory() {
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        echo "Usage: jwdockerimagehistory <image> [--no-trunc]"
        echo "Available images:"
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
# inspectors
# ---------------------------------------------------------------------------------

jwdockerinspectcontainer() {
    # [https://docs.docker.com/config/formatting/]
    # [https://golang.org/pkg/text/template/#hdr-Functions]
    # [https://golang.org/pkg/fmt/]
    if [ $# -eq 0 ]; then
        echo -e "\n\t???"
        docker ps --filter status=running --format "{{.Names}}"
        echo "---"
        docker ps --filter status=created \
                  --filter status=restarting \
                  --filter status=removing \
                  --filter status=paused \
                  --filter status=exited \
                  --filter status=dead --format "{{.Names}}"
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
