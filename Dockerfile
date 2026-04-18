FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor

# প্রয়োজনীয় প্যাকেজ ইন্সটল করা হচ্ছে
RUN apt-get update && apt-get install -y \
    openssh-server sudo curl wget git nano procps net-tools iputils-ping dnsutils lsof htop jq speedtest-cli unzip tree \
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
# 🚀 SYSTEM ALIASES (BUILT-IN)
# ==========================================

alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias md='mkdir -p'
alias sz='du -sh * 2>/dev/null | sort -hr'
alias tree='tree -C'
alias f='find . -name'

alias up='sudo apt-get update && sudo apt-get upgrade -y'
alias clean='sudo apt-get autoremove -y && sudo apt-get clean'
alias mem='free -h'
alias df='df -h'
alias top='htop'
alias ports='sudo netstat -tulpn'
alias logs='sudo tail -f /var/log/syslog'

alias myip='curl -s ifconfig.me; echo'
alias speed='echo -e "\e[1;33m⌛ Testing Speed...\e[0m"; speedtest-cli --simple'
alias ping='ping -c 4'
alias ts='sudo tailscale status'

alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph -n 10'
alias get='wget -c'
alias api='curl -s'
alias weather='curl -s wttr.in?0'

alias apps='echo -e "\n\e[1;36m▶ Node/Python Apps:\e[0m"; ps -eo pid,user,%cpu,%mem,command | grep -E "[n]ode|[p]ython" || echo -e "\e[90mNone\e[0m"'
alias kn='sudo pkill -f node 2>/dev/null; echo -e "\e[1;32m✔ All Node apps stopped.\e[0m"'
alias kp='sudo pkill -f python 2>/dev/null; echo -e "\e[1;32m✔ All Python apps stopped.\e[0m"'

# ==========================================
# 🛠️ CUSTOM SHORTCUT MANAGER
# ==========================================

CUSTOM_ALIAS_FILE="$HOME/.my_shortcuts"
if [ -f "$CUSTOM_ALIAS_FILE" ]; then source "$CUSTOM_ALIAS_FILE"; fi

function addcmd() {
    echo -e "\n\e[1;36m➕ Create a New Shortcut\e[0m\n\e[90m----------------------------------------\e[0m"
    read -p "Shortcut Name (e.g., gohome) : " S_NAME
    if [ -z "$S_NAME" ]; then echo -e "\e[1;31m✘ Cancelled. Name cannot be empty.\e[0m"; return 1; fi
    if grep -q "alias $S_NAME=" "$CUSTOM_ALIAS_FILE" 2>/dev/null; then echo -e "\e[1;33mℹ Shortcut '$S_NAME' already exists! Choose another.\e[0m"; return 1; fi

    read -p "Command to run (e.g., cd ~)  : " S_CMD
    if [ -z "$S_CMD" ]; then echo -e "\e[1;31m✘ Cancelled. Command cannot be empty.\e[0m"; return 1; fi

    echo "alias $S_NAME='$S_CMD'" >> "$CUSTOM_ALIAS_FILE"
    eval "alias $S_NAME='$S_CMD'"
    echo -e "\e[1;32m✔ Shortcut '$S_NAME' created successfully!\e[0m\n"
}

# ==========================================
# ⚡ THE PERFECTLY ALIGNED COMMAND MENU
# ==========================================

function pcmd() { printf "   \e[1;32m%-10s\e[0m : %s\n" "$1" "$2"; }

function cmds() {
    echo -e "\n\e[1;37m⚡ ALL MAGICAL SHORTCUTS ⚡\e[0m"
    echo -e "\e[90m────────────────────────────────────────────────────\e[0m"
    
    echo -e "\e[1;33m📁 Navigation & Files\e[0m"
    pcmd "c" "Clear screen"
    pcmd ".." "Go back 1 folder"
    pcmd "..." "Go back 2 folders"
    pcmd "ll" "List files with details & sizes"
    pcmd "sz" "Show size of folders/files in current dir"
    pcmd "md" "Make a new directory (e.g., md newfolder)"
    pcmd "tree" "Show files in a visual tree structure"
    pcmd "ex <file>" "Extract ANY archive (zip, tar, gz, etc.)"
    
    echo -e "\n\e[1;33m💻 System & Processes\e[0m"
    pcmd "up" "Update and upgrade OS packages"
    pcmd "clean" "Clean system cache and junk files"
    pcmd "mem" "Show RAM usage"
    pcmd "df" "Show Disk space usage"
    pcmd "top" "Open Task Manager (htop)"
    pcmd "ports" "List all currently open ports"
    pcmd "logs" "View live system logs"
    
    echo -e "\n\e[1;33m🎯 App Management\e[0m"
    pcmd "apps" "List all running Node/Python apps"
    pcmd "kn" "Kill all Node.js apps"
    pcmd "kp" "Kill all Python apps"
    pcmd "kport <no>" "Kill app running on a specific port"
    
    echo -e "\n\e[1;33m🌐 Network & VPN\e[0m"
    pcmd "cc" "Connect to Tailscale VPN"
    pcmd "cs" "Disconnect & Stop Tailscale VPN"
    pcmd "ts" "Show Tailscale Status"
    pcmd "myip" "Show Public IP and location info"
    pcmd "speed" "Test Internet Download/Upload speed"
    
    echo -e "\n\e[1;33m🛠️ Tools & Dev\e[0m"
    pcmd "weather" "Show current weather in terminal"
    pcmd "gs, ga, gc" "Git Status, Add, Commit"
    pcmd "addcmd" "Create a personal custom shortcut!"
    
    echo -e "\n\e[1;35m👤 My Personal Shortcuts\e[0m"
    if [ -f "$CUSTOM_ALIAS_FILE" ] && [ -s "$CUSTOM_ALIAS_FILE" ]; then
        cat "$CUSTOM_ALIAS_FILE" | sed "s/alias //g" | sed "s/='/|/g" | sed "s/'//g" | while IFS='|' read -r name cmd; do
            pcmd "$name" "$cmd"
        done
    else
        echo -e "   \e[90mNo personal shortcuts yet. Type 'addcmd' to create one.\e[0m"
    fi
    echo -e "\e[90m────────────────────────────────────────────────────\e[0m\n"
}

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
    
    RAM_MAX=$(cat /sys/fs/cgroup/memory.max 2>/dev/null); RAM_USED_KB=$(ps -eo rss | awk 'NR>1 {sum+=$1} END {if(sum=="") sum=0; print sum}'); RAM_USED_MB=$((RAM_USED_KB / 1024))
    if [[ "$RAM_MAX" =~ ^[0-9]+$ ]]; then RAM_MAX_MB=$((RAM_MAX / 1024 / 1024)); RAM_FREE_MB=$((RAM_MAX_MB - RAM_USED_MB)); R1="${RAM_MAX_MB}MB Max"; R2="${RAM_USED_MB}MB Used"; R3="${RAM_FREE_MB}MB Free"; else R1="Unlimited"; R2="${RAM_USED_MB}MB Used"; R3="---"; fi
    
    MAX_CPU=""
    if [ -f /sys/fs/cgroup/cpu.max ]; then
        QUOTA=$(awk '{print $1}' /sys/fs/cgroup/cpu.max 2>/dev/null); PERIOD=$(awk '{print $2}' /sys/fs/cgroup/cpu.max 2>/dev/null)
        if [ "$QUOTA" != "max" ] && [ -n "$QUOTA" ] && [ "$QUOTA" -gt 0 ] 2>/dev/null; then MAX_CPU=$(( (QUOTA * 100) / PERIOD )); fi
    fi
    if [ -z "$MAX_CPU" ]; then MAX_CPU=200; fi

    # 🛑 THE CPU FIX: শুধুমাত্র কন্টেইনারের ভেতরের প্রসেসগুলোর CPU যোগ করা হচ্ছে (Host leak বন্ধ!) 
    CPU_USED=$(top -b -n 2 -d 0.3 | awk '/^top -/ {i++} i==2 && $1~/^[0-9]+$/ {sum+=$9} END {if(sum=="") sum=0; printf "%.0f", sum}')

    if [ "$CPU_USED" -lt 0 ]; then CPU_USED=0; fi
    if [ "$CPU_USED" -gt "$MAX_CPU" ]; then CPU_USED=$MAX_CPU; fi
    CPU_FREE=$((MAX_CPU - CPU_USED))
    
    C1="${MAX_CPU}% Max"; C2="${CPU_USED}% Used"; C3="${CPU_FREE}% Free"

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
    printf "   \e[1;32m%-10s\e[0m : %s\n" "cc" "Connect VPN"
    printf "   \e[1;32m%-10s\e[0m : %s\n" "up" "Update OS"
    printf "   \e[1;36m%-10s\e[0m : \e[1;36m%s\e[0m\n\n" "cmds" "View ALL Shortcuts ⚡"
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
