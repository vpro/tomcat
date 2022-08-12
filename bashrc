PS1="\[\033[4;1;36m\]\h|${POD_NAMESPACE##*-}:\[\033[0;1;34m\]\w\033[00m\]\$ "
alias cl="cd /data/logs"
alias cc="cd /usr/local/catalina-base"
export LS_OPTIONS='--color=auto'
alias ls='ls $LS_OPTIONS'
alias ll='ls -alF'
alias rm='rm -i'

# See https://askubuntu.com/questions/67283/is-it-possible-to-make-writing-to-bash-history-immediate
shopt -s histappend
export PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

