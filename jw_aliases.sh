# A small collection of miscellaneous useful aliases


export EDITOR=vim

alias diff='colordiff'
alias jwdate='date +%Y-%m-%d'
alias jwdate_l='echo && echo -n "Today:  " && date +%Y-%m-%d && echo && ncal -M && echo'
alias grep='grep --color=auto'
alias jwshred='shred --iterations=0 --zero --remove --verbose'
alias jwmount="mount | grep ^\/dev | awk '{print \$1 \" -> \" \$3}'"
alias jwmount_l='mount | grep ^\/dev'

alias jwytgrep='grep -o [^\"]*\/\watch\?v\=[^\&\"]*'

alias jwsl="screen -ls | grep \"^[[:space:]]\" | tr \".\" \" \" | awk '{print \"   \" \$2}' | sort"
alias jwsl_l='screen -ls'
alias jwsr='screen -r'
alias jwss='screen -S'
