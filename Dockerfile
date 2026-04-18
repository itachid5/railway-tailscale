FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor

# প্রয়োজনীয় প্যাকেজ, নেটওয়ার্ক টুলস এবং Tailscale ইন্সটল করা হচ্ছে
RUN apt-get update && apt-get install -y \
    openssh-server sudo curl wget git nano procps net-tools iputils-ping dnsutils \
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

# ২. কাস্টম ওয়েলকাম মেসেজ, 'mm', 'cc', 'cs' এবং দরকারী শর্টকাট তৈরি
RUN cat > /tmp/setup.sh <<'EOF'

# --- দরকারী শর্টকাট (Aliases) ---
alias ll='ls -alF --color=auto'
alias up='sudo apt-get update && sudo apt-get upgrade -y'
alias clean='sudo apt-get autoremove -y && sudo apt-get clean'
alias myip='curl -s ifconfig.me; echo'
alias ports='sudo netstat -tulpn'

# কাস্টম ওয়েলকাম মেসেজ (MOTD)
function custom_motd() {
    OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2)
    KERNEL_VERSION=$(uname -r)
    ARCH=$(uname -m)
    CPU_MODEL=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//')
    [ -z "$CPU_MODEL" ] && CPU_MODEL="Unknown Virtual CPU"
    
    LAST_LOGIN_FILE="$HOME/.last_login_info"
    if [ -f "$LAST_LOGIN_FILE" ]; then
        LAST_LOGIN=$(cat "$LAST_LOGIN_FILE")
    else
        LAST_LOGIN="First Login / No Record"
    fi
    
    CURRENT_IP=$(echo $SSH_CLIENT | awk '{print $1}')
    echo "$(date +"%A, %d %B %Y %T") from ${CURRENT_IP:-Local}" > "$LAST_LOGIN_FILE"

    echo -e "\e[1;36m╭────────────────────────────────────────────────────────────────────────╮\e[0m"
    echo -e "\e[1;36m│ \e[1;37m🔥 Welcome to Phoenix Server 🔥\e[0m                                        "
    echo -e "\e[1;36m├────────────────────────────────────────────────────────────────────────┤\e[0m"
    echo -e "\e[1;36m│ \e[1;32m💻 OS\e[0m         : ${OS_VERSION}"
    echo -e "\e[1;36m│ \e[1;32m🐧 Kernel\e[0m     : ${KERNEL_VERSION} (${ARCH})"
    echo -e "\e[1;36m│ \e[1;32m⚙️  CPU\e[0m        : ${CPU_MODEL}"
    echo -e "\e[1;36m│ \e[1;32m🕒 Last Login\e[0m : ${LAST_LOGIN}"
    echo -e "\e[1;36m╰────────────────────────────────────────────────────────────────────────╯\e[0m"
}

# সিস্টেম মনিটর ফাংশন
function mm() {
    C_C="\e[36m"; C_G="\e[90m"; C_W="\e[1;37m"; C_R="\e[0m"
    echo -e "\n${C_W}▶ SYSTEM MONITOR${C_R}"
    echo -e "${C_G}------------------------------------------------------------${C_R}"
    print_row() {
        local icon="$1"; local name=$(printf "%-5s" "$2"); local col1=$(printf "%-11s" "$3"); local col2=$(printf "%-11s" "$4"); local col3=$(printf "%-12s" "$5")
        echo -e " ${icon}   ${C_W}${name}${C_R} ${C_G}::${C_R}  ${C_C}${col1}${C_R} ${C_G}|${C_R}  ${C_C}${col2}${C_R} ${C_G}|${C_R}  ${C_C}${col3}${C_R}"
    }
    
    # RAM Calculation
    RAM_MAX=$(cat /sys/fs/cgroup/memory.max 2>/dev/null); RAM_USED_KB=$(ps -eo rss | awk 'NR>1 {sum+=$1} END {if(sum=="") sum=0; print sum}'); RAM_USED_MB=$((RAM_USED_KB / 1024))
    if [[ "$RAM_MAX" =~ ^[0-9]+$ ]]; then RAM_MAX_MB=$((RAM_MAX / 1024 / 1024)); RAM_FREE_MB=$((RAM_MAX_MB - RAM_USED_MB)); R1="${RAM_MAX_MB}MB Max"; R2="${RAM_USED_MB}MB Used"; R3="${RAM_FREE_MB}MB Free"
    else R1="Unlimited"; R2="${RAM_USED_MB}MB Used"; R3="---"; fi
    
    # CPU Calculation (Fixed & Dynamic)
    CORES=$(nproc 2>/dev/null || echo 1)
    MAX_CPU=$((CORES * 100))
    CPU_USED=$(ps -eo %cpu | awk 'NR>1 {sum+=$1} END {printf "%.0f", sum}')
    CPU_FREE=$((MAX_CPU - CPU_USED))
    if [ "$CPU_FREE" -lt 0 ]; then CPU_FREE=0; fi
    C1="${MAX_CPU}% Max"; C2="${CPU_USED}% Used"; C3="${CPU_FREE}% Free"

    # Disk & File Calculation
    D_MAX=$(df -h / | awk 'NR==2 {print $2}'); D_USED=$(df -h / | awk 'NR==2 {print $3}'); D_FREE=$(df -h / | awk 'NR==2 {print $4}'); D1="${D_MAX} Max"; D2="${D_USED} Used"; D3="${D_FREE} Free"
    HOME_USAGE=$(du -sh ~ 2>/dev/null | awk '{print $1}'); F1="---"; F2="${HOME_USAGE} Used"; F3="/home/$USER"
    
    print_row "❖" "RAM" "$R1" "$R2" "$R3"; print_row "⚙" "CPU" "$C1" "$C2" "$C3"; print_row "⛁" "DISK" "$D1" "$D2" "$D3"; print_row "▣" "FILES" "$F1" "$F2" "$F3"
    echo -e "${C_G}------------------------------------------------------------${C_R}\n"
}

# কানেক্ট ফাংশন (cc)
function cc() {
    if pgrep -x "tailscaled" > /dev/null; then
        echo -e "\e[1;33mℹ Tailscale daemon is already running.\e[0m"
    else
        echo -e "\e[1;33m⌛ Starting Tailscale Daemon...\e[0m"
        sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &
        sleep 3
    fi

    TS_KEY_FILE="$HOME/.ts_auth_key"
    TS_KEY=""

    if [ -f "$TS_KEY_FILE" ]; then
        echo -e "\n\e[1;36m🔑 Previous Tailscale Key found!\e[0m"
        echo -e "  \e[1;32m1) Use previous Key\e[0m"
        echo -e "  \e[1;33m2) Enter a new Key\e[0m"
        read -p "Select an option [1 or 2]: " OPTION
        
        if [ "$OPTION" == "1" ]; then
            TS_KEY=$(cat "$TS_KEY_FILE")
            echo -e "\e[1;32m✔ Using previous Key...\e[0m"
        elif [ "$OPTION" == "2" ]; then
            read -p "Enter New Tailscale Auth Key: " TS_KEY
            [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE"
        else
            echo -e "\e[1;31m✘ Invalid option! Process cancelled.\e[0m"
            return 1
        fi
    else
        echo -e "\e[1;36m"
        read -p "Enter Tailscale Auth Key: " TS_KEY
        echo -e "\e[0m"
        [ -n "$TS_KEY" ] && echo "$TS_KEY" > "$TS_KEY_FILE"
    fi

    if [ -z "$TS_KEY" ]; then
        echo -e "\e[1;31m✘ Error: Auth Key cannot be empty!\e[0m"
        return 1
    fi

    echo -e "\e[1;33m⌛ Connecting to Tailscale Network...\e[0m"
    sudo tailscale up --authkey="$TS_KEY" --hostname=phoenix
    
    if [ $? -eq 0 ]; then
        echo -e "\n\e[1;32m✔ Success! Phoenix is now online.\e[0m"
        echo -e "\e[90mIt will keep running in background until you type 'cs'.\e[0m\n"
    else
        echo -e "\n\e[1;31m✘ Failed to connect. Please check your Key.\e[0m\n"
    fi
}

# ডিসকানেক্ট ফাংশন (cs)
function cs() {
    echo -e "\e[1;31m⌛ Disconnecting and stopping Tailscale...\e[0m"
    sudo tailscale logout 2>/dev/null
    sudo tailscale down 2>/dev/null
    sudo pkill -f tailscaled
    echo -e "\e[1;32m✔ Tailscale has been stopped and memory is cleared.\e[0m\n"
}

# লগইন করার পর যা যা দেখাবে
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    clear
    custom_motd
    mm
    echo -e "\e[1;34m⚡ Shortcuts:\e[0m"
    echo -e "   \e[1;33mcc\e[0m    : Connect Tailscale"
    echo -e "   \e[1;31mcs\e[0m    : Stop Tailscale"
    echo -e "   \e[1;36mup\e[0m    : Update & Upgrade System"
    echo -e "   \e[1;36mclean\e[0m : Clean System Cache"
    echo -e "   \e[1;36mports\e[0m : List Open Ports"
    echo -e "   \e[1;36mmyip\e[0m  : Show Public IP\n"
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
