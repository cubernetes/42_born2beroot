#!/usr/bin/env bash

# Needed for neofetch
dnf install -y epel-release

# For fun and convenience
dnf install -y tmux neofetch vim wget sudo

# Add neofetch to bashrc
printf '\nneofetch\n' >> /root/.bashrc
printf '\nneofetch\n' >> /home/tischmid/.bashrc

# Custom bash prompt
echo -n 'PS1=$'\''\\[\\033[31m\\]\\u\\[\\033[m\\]@\\[\\033[32m\\]\\h\\[\\033[m\\]@\\[\E[35m\\]tmux\\[\E[m\\] \\[\\033[33m\\][\\w]\\[\\033[m\\]\\n\\[\\033[35m\\]~\\$\\[\\033[m\\] '\''' >> /home/tischmid/.bashrc
echo -n 'PS1=$'\''\\[\\033[31m\\]\\u\\[\\033[m\\]@\\[\\033[32m\\]\\h\\[\\033[m\\]@\\[\E[35m\\]tmux\\[\E[m\\] \\[\\033[33m\\][\\w]\\[\\033[m\\]\\n\\[\\033[35m\\]~\\$\\[\\033[m\\] '\''' >> /root/.bashrc

# Molokai colorscheme for vim
mkdir --parent /root/.vim/colors
wget -O /root/.vim/colors/molokai.vim \
	https://raw.githubusercontent.com/tomasr/molokai/master/colors/molokai.vim

# vimrc
cat << 'VIMRC' > /root/.vimrc
syntax enable
set tabstop=4
set shiftwidth=4
set cursorline

set background=dark
colorscheme molokai

set autoindent
set smartindent
set cindent

set relativenumber
set laststatus=2
set showcmd

set noswapfile
set hlsearch

set ruler

" Ignore case when searching
set ignorecase

" When searching try to be smart about cases
set smartcase

" Highlight search results
set hlsearch

" Makes search act like search in modern browsers
set incsearch

" Don't redraw while executing macros (good performance config)
set lazyredraw

" Show matching brackets when text indicator is over them
set showmatch

let vimDir = '$HOME/.vim'

if stridx(&runtimepath, expand(vimDir)) == -1
  " vimDir is not on runtimepath, add it
  let &runtimepath.=','.vimDir
endif

" Keep undo history across sessions by storing it in a file
if has('persistent_undo')
    let myUndoDir = expand(vimDir . '/undodir')
    " Create dirs
    call system('mkdir ' . vimDir)
    call system('mkdir ' . myUndoDir)
    let &undodir = myUndoDir
    set undofile
endif

" Return to last edit position when opening files (You want this!)
autocmd BufReadPost *
     \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"zz" |
     \ endif

VIMRC

# Change some lines in the sshd_config
sed -e 's/^\s*#\?\s*Port\s*[[:digit:]].*/Port 4242/' \
	-e 's/^\s*#\?\s*PermitRootLogin\s.*/PermitRootLogin no/' \
	-e 's/^\s*#\?\s*PasswordAuthentication\s.*/PasswordAuthentication yes/' \
	-i \
	/etc/ssh/sshd_config

# For the semanage tool
dnf install -y policycoreutils-python-utils

# Allow port 4242 for ssh
# -a : add new rule
# -t <type> : rule type to add
semanage port -a -t ssh_port_t -p tcp 4242

# Add 4242 to firewall
firewall-offline-cmd --add-port=4242/tcp

# Reload sshd service
systemctl reload sshd

# Set hostname (not needed, already done by the kickstart script)
# hostnamectl set-hostname tischmid42

# Overwrite /etc/hosts
cat << 'HOSTS' > /etc/hosts
127.0.0.1     localhost localhost.localdomain localhost4 localhost4.localdomain
127.0.1.1     tischmid42 tischmid42.localdomain
::1           localhost localhost.localdomain localhost6 localhost6.localdomain
HOSTS

# Set max age, min age and warn days for passwords.
sed -e 's/^\s*#\?\s*PASS_MAX_DAYS\s*[[:digit:]].*/PASS_MAX_DAYS 30/' \
	-e 's/^\s*#\?\s*PASS_MIN_DAYS\s*[[:digit:]].*/PASS_MIN_DAYS 2/' \
	-e 's/^\s*#\?\s*PASS_WARN_AGE\s*[[:digit:]].*/PASS_WARN_AGE 7/' \
	-i \
	/etc/login.defs

# Make PAM enforce strong password policies.
sed -e 's/.*pam_pwquality.*/password\trequisite\tpam_pwquality.so\ttry_first_pass local_users_only retry=3 authtok_type= minlen=10 ucredit=-1 lcredit=-1 dcredit=-1 difok=7 maxrepeat=3 reject_username enforce_for_root/' \
	-i \
	/etc/pam.d/system-auth
sed -e 's/.*pam_pwquality.*/password\trequisite\tpam_pwquality.so\ttry_first_pass local_users_only retry=3 authtok_type= minlen=10 ucredit=-1 lcredit=-1 dcredit=-1 difok=7 maxrepeat=3 reject_username enforce_for_root/' \
	-i \
	/etc/pam.d/password-auth

# Max retries=3 for sudo password
printf '\nDefaults\tpasswd_tries=3\n' >> /etc/sudoers

# Custom error message
printf 'Defaults\tbadpass_message="\033[31mYou shall not pass!\033[m"\n' >> /etc/sudoers

# Log inputs and ouputs
printf 'Defaults\tlog_input\n' >> /etc/sudoers
printf 'Defaults\tlog_output\n' >> /etc/sudoers
printf 'Defaults\tiolog_dir="/var/log/sudo/"\n' >> /etc/sudoers
printf 'Defaults\tlogfile="/var/log/sudo/sudo.log"\n' >> /etc/sudoers

# Don't allow sudo to be scripted
printf 'Defaults\trequiretty\n' >> /etc/sudoers

# Secure Path
printf 'Defaults\tsecure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"\n' >> /etc/sudoers

# Monitoring script
cat << 'MONITORING_SCRIPT' > /usr/local/bin/monitoring.sh
#!/usr/bin/env bash

# Kill all other monitoring scripts
ps auxww | grep -v grep | grep -v "${$}" | grep 'monitoring.sh' | awk '{print $2}' | xargs -rn1 kill -9

# Repeat every 600 seconds (10 minutes)
while : ; do

# Wait 30 so there's time for a user to log in
sleep 30

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
MONITORING_SCRIPT

# Make monitoring script executable
chmod +x /usr/local/bin/monitoring.sh

# Add delay file
printf '570' >> /etc/monitoring_delay

# Add crontab
printf '\n@reboot root /usr/local/bin/monitoring.sh\n' >> /etc/crontab
