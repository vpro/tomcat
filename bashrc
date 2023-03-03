
# \[..\]: instruct bash that this does not take up any space (they are ANSI control characters)
PS1="\[\033[4;1;36m\]\h|${POD_NAMESPACE##*-}:\[\033[0;1;34m\]\w\[\033[00m\]\$ "
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
    re='^[0-9]+L?$' # optionally postfixed with L (as a java constant)
    if [[ $input == "" ]] ; then
        nanoseconds=$(date  +%s%N)
        echo $((nanoseconds / 1000000))
    elif [[ $input =~ $re ]] ; then
        input=${input//L/}
        if (( $input > 9999999999 )) ; then
            input=$((input / 1000))
        fi
        date --date="@$input" -Iseconds
    else
        nanoseconds=$(date --date="$input" +%s%N)
        echo $((nanoseconds / 1000000))
    fi
}

# Show the uptime of the java application
function aptime() {
    col="\033[50D\033[30C"
    pid=$(ps x | grep java | grep -v 'grep' | awk '{print $1}')
    echo -e "pid:$col$pid"
    starttime=$(ps -p $pid -o etimes -h 2> /dev/null | awk 'BEGIN{now=systime()} {print strftime("%Y-%m-%dT%H:%M:%S%z", now - $1);}')
    echo -e "starttime:$col$starttime"
    uptime=$(ps -p $pid -o etime -h 2> /dev/null | xargs echo)
    echo -e "uptime:$col$uptime"
    echo -e "java version:$col${JAVA_VERSION}"
    echo -e "tomcat version:$col${TOMCAT_VERSION}"

    cat /DOCKER.BUILD | awk -F= "{print \$1\":$col\"\$2}"

}

