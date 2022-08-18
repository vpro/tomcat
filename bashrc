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

# converts iso datetime format to millis since epoch if input is not an integer
# convert millis since epoch or seconds since epoch (for small numbers) to iso date time
# shows current time in millis since epoch if no input
# handy since our json contains millis since epoch
function ts() {
    input=$1
    re='^[0-9]+$'
    if [[ $input == "" ]] ; then
        nanoseconds=$(date  +%s%N)
        echo $((nanoseconds / 1000000))
    elif [[ $input =~ $re ]] ; then
        if (( $input > 9999999999 )) ; then
            input=$((input / 1000))
        fi
        date --date="@$input" -Iseconds
    else
        nanoseconds=$(date --date="$input" +%s%N)
        echo $((nanoseconds / 1000000))
    fi
}

