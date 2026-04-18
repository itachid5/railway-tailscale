FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor

# প্রয়োজনীয় প্যাকেজ ইন্সটল করা হচ্ছে
RUN apt-get update && apt-get install -y \
    openssh-server sudo curl wget git nano procps net-tools iputils-ping dnsutils lsof htop jq speedtest-cli unzip \
    && curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*

# SSH ফোল্ডার তৈরি এবং ইউজার/পাসওয়ার্ড সেটআপ
RUN mkdir -p /var/run/sshd && \
    useradd -m -s /bin/bash -u 1000 devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "devuser:123456" | chpasswd && \
    echo "root:123456" | chpasswd && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# ডিফল্ট ওয়েলকাম মেসেজ বন্ধ করা হচ্ছে
RUN rm -rf /etc/update-motd.d/* && \
    rm -f /etc/legal && \
    rm -f /etc/motd && \
    touch /home/devuser/.hushlogin && \
    touch /root/.hushlogin

# ১. প্রম্পট (PS1) স্টাইল সেটআপ
RUN echo "export PS1='\[\e[1;32m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ '" >> /home/devuser/.bashrc && \
    echo "export PS1='\[\e[1;31m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]# '" >> /root/.bashrc

# ২. সমস্ত ফাংশন এবং সুপার শর্টকাট
RUN cat > /tmp/setup.sh <<'EOF'

# ==========================================
# 🚀 THE ULTIMATE SHORTCUTS
# ==========================================

alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias x='exit'
alias h='history'
alias md='mkdir -p'
alias ll='ls -alF --color=auto'
alias sz='du -sh * 2>/dev/null | sort -hr'
alias f='find . -name'

alias up='sudo apt-get update && sudo apt-get upgrade -y'
alias clean='sudo apt-get autoremove -y && sudo apt-get clean'
alias mem='free -m'
alias top='htop'
alias df='df -h'
alias weather='curl -s wttr.in?0'

alias myip='curl -s ifconfig.me; echo'
alias speed='echo -e "\e[1;33m⌛ Testing Speed...\e[0m"; speedtest-cli --simple'
alias ports='sudo netstat -tulpn'
alias ping='ping -c 4'
alias ts='sudo tailscale status'

alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph -n 10'
alias get='wget -c'
alias api='curl -s'

alias apps='echo -e "\n\e[1;36m▶ Node/Python Apps:\e[0m"; ps -eo pid,user,%cpu,%mem,command | grep -E "[n]ode|[p]ython" || echo -e "\e[90mNone\e[0m"'
alias kn='sudo pkill -f node 2>/dev/null; echo -e "\e[1;32m✔ All Node apps stopped.\e[0m"'
alias kp='sudo pkill -f python 2>/dev/null; echo -e "\e[1;32m✔ All Python apps stopped.\e[0m"'

function kport() {
    if [ -z "$1" ]; then echo -e "\e[1;31m✘ Usage: kport <port>\e[0m"; return 1; fi
    PID=$(sudo lsof -t -i:$1)
    if [ -z "$PID" ]; then echo -e "\e[1;33mℹ Port $1 is free\e[0m"
    else sudo kill -9 $PID; echo -e "\e[1;32m✔ Killed process on port $1\e[0m"; fi
}

function ex() {
    if [ -z "$1" ]; then echo -e "\e[1;31m✘ Usage: ex <filename>\e[0m"; return 1; fi
    if [ -f "$1" ] ; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;; *.tar.gz) tar xzf "$1" ;; *.bz2) bunzip2 "$1" ;;
            *.rar) unrar e "$1" ;; *.gz) gunzip "$1" ;; *.tar) tar xf "$1" ;;
            *.zip) unzip "$1" ;; *) echo -e "\e[1;31m✘ Cannot extract '$1'\e[0m" ;;
        esac
    else echo -e "\e[1;31m✘ '$1' is not a valid file\e[0m"; fi
}

# ==========================================
# 📊 UI & DASHBOARD FUNCTIONS
# ==========================================

function cmds() {
    echo -e "\n\e[1;37m⚡ ALL MAGICAL SHORTCUTS ⚡\e[0m"
    echo -e "\e[90m─────────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;33m📁 Nav & File\e[0m  | \e[1;36mc\e[0m (Clear), \e[1;36m..\e[0m (Back), \e[1;36mll\e[0m (List), \e[1;36msz\e[0m (Size)"
    echo -e "               | \e[1;36mmd\e[0m (Mkdir), \e[1;36mf\e[0m (Find), \e[1;36mex\e[0m (Extract), \e[1;36mx\e[0m (Exit)"
    echo -e "\e[90m─────────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;33m💻 Sys & Dev\e[0m   | \e[1;32mup\e[0m (Update), \e[1;32mclean\e[0m (Clean), \e[1;32mtop\e[0m (htop)"
    echo -e "               | \e[1;32mapps\e[0m (List), \e[1;31mkn\e[0m (Kill Node), \e[1;31mkp\e[0m (Kill Py)"
    echo -e "               | \e[1;31mkport <no>\e[0m (Kill Port), \e[1;32mgs/ga/gc/gp\e[0m (Git)"
    echo -e "\e[90m─────────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;33m🌐 Net & VPN\e[0m   | \e[1;35mcc\e[0m (Connect), \e[1;31mcs\e[0m (Stop VPN), \e[1;35mts\e[0m (VPN Status)"
    echo -e "               | \e[1;35mmyip\e[0m (IP Info), \e[1;35mspeed\e[0m (Speedtest), \e[1;35mports\e[0m"
    echo -e "\e[90m─────────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;33m🛠️ Tools\e[0m       | \e[1;34mweather\e[0m (Weather), \e[1;34mget\e[0m (Wget), \e[1;34mapi\e[0m (Curl)\n"
}

function custom_motd() {
    OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2); KERNEL_VERSION=$(uname -r); ARCH=$(uname -m)
    CPU_MODEL=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//'); [ -z "$CPU_MODEL" ] && CPU_MODEL="Unknown Virtual CPU"
    LAST_LOGIN_FILE="$HOME/.last_login_info"; if [ -f "$LAST_LOGIN_FILE" ]; then LAST_LOGIN=$(cat "$LAST_LOGIN_FILE"); else LAST_LOGIN="First Login"; fi
    CURRENT_IP=$(echo $SSH_CLIENT | awk '{print $1}'); echo "$(date +"%A, %d %B %Y %T") from ${CURRENT_IP:-Local}" > "$LAST_LOGIN_FILE"
    UPTIME_SEC=$(ps -o etimes= -p 1 2>/dev/null | xargs)
    if [ -n "$UPTIME_SEC" ] && [[ "$UPTIME_SEC" =~ ^[0-9]+$ ]]; then d=$((UPTIME_SEC / 86400)); h=$(( (UPTIME_SEC % 86400) / 3600 )); m=$(( (UPTIME_SEC % 3600) / 60 )); if [ $d -gt 0 ]; then MY_UPTIME="${d} days, ${h} hours, ${m} mins"; elif [ $h -gt 0 ]; then MY_UPTIME="${h} hours, ${m} mins"; else MY_UPTIME="${m} mins"; fi; else MY_UPTIME="Just started"; fi

    echo -e "\e[1;36m╭────────────────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "\e[1;36m│ \e[1;37m🔥 Welcome to Phoenix Server 🔥\e[0m                                        "
    echo -e "\e[1;36m├────────────────────────────────────────────────────────────────────────┤\e[0m"
    echo -e "\e[1;36m│ \e[1;32m💻 OS\e[0m         : ${OS_VERSION}"
    echo -e "\e[1;36m│ \e[1;32m🐧 Kernel\e[0m     : ${KERNEL_VERSION} (${ARCH})"
    echo -e "\e[1;36m│ \e[1;32m⚙️  CPU\e[0m        : ${CPU_MODEL}"
    echo -e "\e[1;36m│ \e[1;32m⏳ Uptime\e[0m     : ${MY_UPTIME}"
    echo -e "\e[1;36m│ \e[1;32m🕒 Last Login\e[0m : ${LAST_LOGIN}"
    echo -e "\e[1;36m╰────────────────────────────────────────────────────────────────────────╯\e[0m"
}

function mm() {
    C_C="\e[36m"; C_G="\e[90m"; C_W="\e[1;37m"; C_R="\e[0m"
    echo -e "\n${C_W}▶ SYSTEM MONITOR${C_R}\n${C_G}------------------------------------------------------------${C_R}"
    print_row() { echo -e " $1   ${C_W}$(printf "%-5s" "$2")${C_R} ${C_G}::${C_R}  ${C_C}$(printf "%-11s" "$3")${C_R} ${C_G}|${C_R}  ${C_C}$(printf "%-11s" "$4")${C_R} ${C_G}|${C_R}  ${C_C}$(printf "%-12s" "$5")${C_R}"; }
    
    # RAM Calculation
    RAM_MAX=$(cat /sys/fs/cgroup/memory.max 2>/dev/null); RAM_USED_KB=$(ps -eo rss | awk 'NR>1 {sum+=$1} END {if(sum=="") sum=0; print sum}'); RAM_USED_MB=$((RAM_USED_KB / 1024))
    if [[ "$RAM_MAX" =~ ^[0-9]+$ ]]; then RAM_MAX_MB=$((RAM_MAX / 1024 / 1024)); RAM_FREE_MB=$((RAM_MAX_MB - RAM_USED_MB)); R1="${RAM_MAX_MB}MB Max"; R2="${RAM_USED_MB}MB Used"; R3="${RAM_FREE_MB}MB Free"; else R1="Unlimited"; R2="${RAM_USED_MB}MB Used"; R3="---"; fi
    
    # CPU Calculation (2 vCPU Limit Check)
    MAX_CPU=""
    if [ -f /sys/fs/cgroup/cpu.max ]; then
        QUOTA=$(awk '{print $1}' /sys/fs/cgroup/cpu.max 2>/dev/null); PERIOD=$(awk '{print $2}' /sys/fs/cgroup/cpu.max 2>/dev/null)
        if [ "$QUOTA" != "max" ] && [ -n "$QUOTA" ] && [ "$QUOTA" -gt 0 ] 2>/dev/null; then MAX_CPU=$(( (QUOTA * 100) / PERIOD )); fi
    fi
    if [ -z "$MAX_CPU" ]; then MAX_CPU=200; fi

    # REAL-TIME CPU Usage Calculation via cgroups (0.2s snapshot)
    CPU_USED=0
    if [ -f /sys/fs/cgroup/cpu.stat ]; then
        u1=$(awk '/^usage_usec/ {print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null || echo 0)
        sleep 0.2
        u2=$(awk '/^usage_usec/ {print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null || echo 0)
        delta=$((u2 - u1))
        [ "$delta" -gt 0 ] && CPU_USED=$((delta / 2000))
    elif [ -f /sys/fs/cgroup/cpuacct/cpuacct.usage ]; then
        u1=$(cat /sys/fs/cgroup/cpuacct/cpuacct.usage 2>/dev/null || echo 0)
        sleep 0.2
        u2=$(cat /sys/fs/cgroup/cpuacct/cpuacct.usage 2>/dev/null || echo 0)
        delta=$((u2 - u1))
        [ "$delta" -gt 0 ] && CPU_USED=$((delta / 2000000))
    else
        CPU_USED=$(top -bn1 | awk '/Cpu/ {print $2}' | cut -f 1 -d ".")
    fi

    if [ "$CPU_USED" -lt 0 ]; then CPU_USED=0; fi
    if [ "$CPU_USED" -gt "$MAX_CPU" ]; then CPU_USED=$MAX_CPU; fi
    CPU_FREE=$((MAX_CPU - CPU_USED))
    
    C1="${MAX_CPU}% Max"; C2="${CPU_USED}% Used"; C3="${CPU_FREE}% Free"

    # Disk & Files
    D_MAX=$(df -h / | awk 'NR==2 {print $2}'); D_USED=$(df -h / | awk 'NR==2 {print $3}'); D_FREE=$(df -h / | awk 'NR==2 {print $4}'); D1="${D_MAX} Max"; D2="${D_USED} Used"; D3="${D_FREE} Free"
    HOME_USAGE=$(du -sh ~ 2>/dev/null | awk '{print $1}'); F1="---"; F2="${HOME_USAGE} Used"; F3="/home/$USER"
    
    print_row "❖" "RAM" "$R1" "$R2" "$R3"; print_row "⚙" "CPU" "$C1" "$C2" "$C3"; print_row "⛁" "DISK" "$D1" "$D2" "$D3"; print_row "▣" "FILES" "$F1" "$F2" "$F3"
    echo -e "${C_G}------------------------------------------------------------${C_R}\n"
}

# কানেক্ট ফাংশন (cc) এবং (cs)
function cc() {
    if pgrep -x "tailscaled" > /dev/null; then echo -e "\e[1;33mℹ Tailscale daemon is running.\e[0m"
    else echo -e "\e[1;33m⌛ Starting Tailscale...\e[0m"; sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 & sleep 3; fi

    TS_KEY_FILE="$HOME/.ts_auth_key"; TS_KEY=""
    if [ -f "$TS_KEY_FILE" ]; then
        echo -e "\n\e[1;36m🔑 Previous Key found!\e[0m\n  \e[1;32m1) Use previous Key\e[0m\n  \e[1;33m2) Enter new Key\e[0m"; read -p "Option [1/2]: " OPTION
        if [ "$OPTION" == "1" ]; then TS_KEY=$(cat "$TS_KEY_FILE"); elif [ "$OPTION" == "2" ]; then read -p "New Key: " TS_KEY; [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE"; else return 1; fi
    else
        echo -e "\e[1;36m"; read -p "Enter Tailscale Auth Key: " TS_KEY; echo -e "\e[0m"; [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE"
    fi
    [ -z "$TS_KEY" ] && return 1
    sudo tailscale up --authkey="$TS_KEY" --hostname=phoenix
    if [ $? -eq 0 ]; then echo -e "\n\e[1;32m✔ Success! Phoenix is online.\e[0m\n"; else echo -e "\n\e[1;31m✘ Failed.\e[0m\n"; fi
}
function cs() { sudo tailscale logout 2>/dev/null; sudo tailscale down 2>/dev/null; sudo pkill -f tailscaled; echo -e "\e[1;32m✔ Tailscale stopped.\e[0m\n"; }

# --- 🚀 CLEAN LOGIN SCREEN ---
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    clear
    custom_motd
    mm
    echo -e "\e[1;33m🔥 Quick Actions:\e[0m"
    echo -e "   \e[1;32mcc\e[0m   : Connect VPN"
    echo -e "   \e[1;32mup\e[0m   : Update OS"
    echo -e "   \e[1;36mcmds\e[0m : \e[1;36mView ALL Shortcuts ⚡\e[0m\n"
fi
EOF

RUN cat /tmp/setup.sh >> /home/devuser/.bashrc && \
    cat /tmp/setup.sh >> /root/.bashrc && \
    rm /tmp/setup.sh

# ৩. স্টার্টআপ স্ক্রিপ্ট
RUN cat > /start.sh <<'SH'
#!/bin/bash
set -e
/usr/sbin/sshd
tail -f /dev/null
SH

RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

WORKDIR /root
EXPOSE 22
CMD ["/start.sh"]
