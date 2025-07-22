alias jwdlf="docker logs -f"
alias jwdockerfindcontainerbyip="docker ps -q | xargs -n 1 docker inspect -f '{{.Id}} {{.Name}}  -  {{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' | grep"


# ---------------------------------------------------------------------------------
# ps 
# ---------------------------------------------------------------------------------

alias jwdockerps="docker ps --format \"table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\""


jwdockerpsdown() {
    docker ps --filter status=created \
              --filter status=restarting \
              --filter status=removing \
              --filter status=paused \
              --filter status=exited \
              --filter status=dead --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
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
    docker inspect -f 'Id:            {{ .Id }}' $CONTAINER
    docker inspect -f 'Hostname:      {{ .Config.Hostname }} ({{ .Name }})' $CONTAINER
    docker inspect -f 'Image:         {{ .Config.Image }}' $CONTAINER
    docker inspect -f 'Path:          {{ .Path }}' $CONTAINER
    docker inspect -f 'Command:       {{json .Config.Cmd }}' $CONTAINER
    docker inspect -f 'Entrypoint:    {{json .Config.Entrypoint }}' $CONTAINER
    docker inspect -f 'User:          {{ .Config.User }}' $CONTAINER
    docker inspect -f 'WorkDir:       {{ .Config.WorkingDir }}' $CONTAINER
    docker inspect -f 'ExtraHosts:    {{json .HostConfig.ExtraHosts }}' $CONTAINER
    docker inspect -f 'RestartCount:  {{ .RestartCount }}' $CONTAINER
    echo
    echo "---[ Ports ]-------------------------------------------"
    docker inspect -f '{{ range $key, $value := .NetworkSettings.Ports }}{{printf "%s -> %s\n" $value $key}}{{ end }}' $CONTAINER
    echo "---[ Volumes ]-----------------------------------------"
    docker inspect -f '{{ range $item := .Mounts }}{{printf "\"%s\" [%s]  ->  %s : %s\n" .Type .Mode .Source .Destination}}{{ end }}' $CONTAINER
    echo "---[ Networks ]----------------------------------------"
    docker inspect -f '{{ range $key, $value := .NetworkSettings.Networks }}{{printf "\"%s\"  [NetworkID: %s]  -->  IP: %s , Aliases: %s\n" $key .NetworkID .IPAddress .Aliases}}{{ end }}' $CONTAINER
    echo "---[ RestartPolicy ]-----------------------------------"
    docker inspect -f '{{ range $key, $value := .HostConfig.RestartPolicy }}{{ printf "  %-22s" $key }}{{ $value }}{{ printf "\n" }}{{ end }}' $CONTAINER
    echo "---[ Labels ]------------------------------------------"
    docker inspect -f '{{ range $key, $value := .Config.Labels }}{{ printf "  %-40s" $key }}{{ $value }}{{ printf "\n" }}{{ end }}' $CONTAINER
    echo "---[ Env ]---------------------------------------------"
    docker inspect -f '{{ range $item := .Config.Env }}{{ range $ii := split $item "=" }}{{printf "  %-30s" $ii}}{{ end }}{{"\n"}}{{ end }}' $CONTAINER | grep -v "^$" | sort ; echo
    echo "---[ State ($(docker inspect  -f '{{ .State.Status }}' $CONTAINER)) ]---------------------------------"
    docker inspect -f '{{ range $key, $value := .State }}{{ printf "  %-15s" $key }}{{ $value }}{{ printf "\n" }}{{ end }}' $CONTAINER
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
    docker inspect -f 'Id:         {{ .Id }}  [{{ .Name }}]' $NETWORK
    docker inspect -f 'Scope:      {{ .Scope }}' $NETWORK
    docker inspect -f 'Driver:     {{ .Driver }}' $NETWORK
    docker inspect -f '{{ range $item := .IPAM.Config }}{{ range $key, $value := $item }}{{printf "%s\t\t%s\n" $key $value}}{{ end }}{{ end }}' $NETWORK
    echo "-------------- Containers:"
    docker network inspect -f '{{ range $key, $value := .Containers }}{{printf "%s: [%s]  %s\n" $key .IPv4Address .Name}}{{ end }}' $NETWORK
}
