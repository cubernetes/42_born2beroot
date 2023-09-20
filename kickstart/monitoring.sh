#!/usr/bin/env bash

# Kill all other monitoring scripts
ps auxww | grep -v grep | grep -v "${$}" | grep 'monitoring.sh' | awk '{print $2}' | xargs -rn1 kill -9

# Repeat every 600 seconds (10 minutes)
while : ; do

# Wait 60 so there's time for a user to log in
sleep 60

logical_cores="$( lscpu -p | grep -v '^#' | wc -l )"
physical_cores="$( lscpu -p | grep -v '^#' | sort -u -t',' -k'2,4' | wc -l )"

ram_absolute_free="$(free -h | grep '^Mem:' | awk '{ print $4 }')"
ram_absolute_total="$(free -h | grep '^Mem:' | awk '{ print $2 }')"
ram_percent_free="$(free -b | grep '^Mem:' | awk '{ printf("%.2f%%"), $3/$2*100}')"
memory_absolute_free="$(free -ht | grep '^Total:' | awk '{ print $4 }')"
memory_absolute_total="$(free -ht | grep '^Total:' | awk '{ print $2 }')"
memory_percent_free="$(free -bt | grep '^Total:' | awk '{ printf("%.2f%%"), $3/$2*100}')"
cpu_percent_used="$(top -bn1 | grep '^%Cpu(s)' | cut -d':' -f2 | awk '{ printf("%.1f%%"), $1 + $3 }')"

last_reboot="$(who -b | grep system | awk '{ print $3 " " $4 }')"

lvm_status="$([ $(grep '/dev/mapper/' /etc/fstab | wc -l) = "0" ] && echo inactive || echo active)"

no_active_tcps="$(ss -s | grep 'TCP:' | awk '{ print $4 }' | sed 's/,//')"

# command-space separated list of all users with a login shell.
# Fails if a username contain the strings " ttyD" or " pts/D" without quotes
# where D is a decimal digit.
users="$(w |
	sed -e 's/[[:blank:]]*tty[[:digit:]].*//;s/[[:blank:]]*pts\/[[:digit:]].*//;1,2d' |
	xargs printf '%s, ' |
	sed -e 's/, $//'
)"

# Alternatively: "$(who -q | tail -1 | cut -d'=' -f2)"
no_active_users="$(w |
	sed -e '1,2d' |
	wc -l
)"

sudo_invocs="$(2>/dev/null journalctl _COMM=sudo | grep COMMAND | wc -l)"

# Get the pretty name from os-release to variable
source <(grep PRETTY /etc/os-release)

if command -v curl 2>/dev/null 1>&2; then
        wan_ipv4="$(curl -sL -4 http://ident.me)"
        wan_ipv6="$(curl -sL -6 http://v6.ident.me)"
elif command -v wget 2>/dev/null 1>&2; then
        wan_ipv4="$(wget -qO- --inet4-only http://ident.me)"
        wan_ipv6="$(wget -qO- --inet6-only http://v6.ident.me)"
else
        wan_ipv4="Neither curl nor wget installed!"
fi
if [ -z "${wan_ipv4}" ]; then
        wan_ipv4="<None>"
fi
if [ -z "${wan_ipv6}" ]; then
        wan_ipv6="<None>"
fi

if_ipv4s="$(
        find /sys/class/net -mindepth 1 -not -name 'lo' -exec basename {} \; | xargs -I{} sh -c '
                ipv4s="$(ip addr show {} | grep "inet[^6]")"
                if [ -n "${ipv4s}" ]; then
                                                printf "${ipv4s}" | awk "{ printf \"%31s%-43s \0\", \"\", \$2 }" |
                                                        xargs -0 -ILINE printf "LINE(%-18s %s)\n" "$(ip addr show {} | { grep link/ether || printf "dummy <N/A>"; } | awk "{ print \$2 \",\" }")" "{}"
                fi
        '
)"

if_ipv6s="$(
        find /sys/class/net -mindepth 1 -not -name 'lo' -exec basename {} \; | xargs -I{} sh -c '
                ipv6s="$(ip addr show {} | grep "inet6")"
                if [ -n "${ipv6s}" ]; then
                                                printf "${ipv6s}" | awk "{ printf \"%31s%-43s \0\", \"\", \$2 }" |
                                                        xargs -0 -ILINE printf "LINE(%-18s %s)\n" "$(ip addr show {} | { grep link/ether || printf "dummy <N/A>"; } | awk "{ print \$2 \",\" }")" "{}"
                fi
        '
)"

for pts in $(echo "$(w | sed -e '1,2d;' | awk '{print $2}'; cd /dev; ls pts/*)" | sort -u); do

2>/dev/null ps -t /dev/"${pts}" | 2>/dev/null 1>&2 grep 'tmux: client' && continue
2>/dev/null ps -t /dev/"${pts}" | 2>/dev/null 1>&2 grep '[[:digit:]] su$' && continue

sed -e 's/$/\r/g' << MSG | 2>/dev/null 1>&2 tee >"/dev/${pts}"

VM State:
 - Last Reboot:                ${last_reboot}
 - Operating System:           $(uname -o), ${PRETTY_NAME}
 - Architecture:               $(uname -m)
 - Kernel:                     $(uname -s)
 - Kernel Release:             $(uname -r)
 - Physical Processors:        ${physical_cores}
 - Logical Processors:         ${logical_cores}
 - RAM Usage:                  ${ram_percent_free} of ${ram_absolute_total} (free ${ram_absolute_free})
 - Memory Usage (RAM + Swap):  ${memory_percent_free} of ${memory_absolute_total} (free ${memory_absolute_free})
 - CPU Usage:                  ${cpu_percent_used}
 - LVM Status:                 ${lvm_status}
 - Active TCP Connections:     ${no_active_tcps}
 - Currently logged in Users:  ${no_active_users} (${users})
 - Number of sudo invocations: ${sudo_invocs}
 - WAN IPv4 Address:           ${wan_ipv4}
 - WAN IPv6 Address:           ${wan_ipv6}
 - Interface IPv4 Addresses:
${if_ipv4s}
 - Interface IPv6 Addresses:
${if_ipv6s}
MSG

done

sleep "$(cat /etc/monitoring_delay)"
done &
