# This is a replacement to the default /etc/bash.bashrc which does all kind of stuf not really useful in docker.
# E.g. it calls 'groups', which result in warnings like:
# groups: cannot find name for group ID 1001570000

# System-wide .bashrc file for interactive bash(1) shells.

# To enable the settings / commands in this file for login shells as well,
# this file has to be sourced in /etc/profile.

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize


