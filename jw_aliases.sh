# A small collection of miscellaneous useful aliases


alias grep='grep --color=auto'
alias diff='colordiff'
alias jwwdiff="wdiff -n -w $'\033[30;41m' -x $'\033[0m'  -y $'\033[30;42m' -z $'\033[0m'"

alias jwdate='date +%Y-%m-%d'
alias jwdatel='echo && echo -n "Today:  " && date +%Y-%m-%d && echo && ncal -M && echo'

alias jwshred='shred --iterations=0 --zero --remove --verbose'

alias jwmount="mount | grep ^\/dev | awk '{print \$1 \" -> \" \$3}'"
alias jwmountl='mount | grep ^\/dev'
alias jwdf='df -hT | egrep "ext4|xfs"'

# ---[ screen ]---
alias jwsl="screen -ls | grep \"^[[:space:]]\" | tr \".\" \" \" | awk '{print \"   \" \$2}' | sort"
alias jwsll='screen -ls'
alias jwsr='screen -r'
alias jwss='screen -S'
