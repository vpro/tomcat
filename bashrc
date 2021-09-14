export PS1="${debian_chroot:+($debian_chroot)}\u@\h|${POD_NAMESPACE##*-}:\w\$ "
alias cl="cd /data/logs"
alias cc="cd /usr/local/catalina-base"
export LS_OPTIONS='--color=auto'
alias ls='ls $LS_OPTIONS'
alias ll='ls -alF'
alias rm='rm -i'
