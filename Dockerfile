FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor

# প্রয়োজনীয় প্যাকেজ এবং Tailscale ইন্সটল করা হচ্ছে
RUN apt-get update && apt-get install -y \
    openssh-server sudo curl wget git nano procps \
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

# --- উবুন্টুর ডিফল্ট ওয়েলকাম মেসেজ (MOTD) এবং 'unminimize' মেসেজ বন্ধ করা হচ্ছে ---
RUN rm -rf /etc/update-motd.d/* && \
    rm -f /etc/legal && \
    rm -f /etc/motd && \
    touch /home/devuser/.hushlogin && \
    touch /root/.hushlogin

# ১. প্রম্পট (PS1) স্টাইল সেটআপ
RUN echo "export PS1='\[\e[1;32m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ '" >> /home/devuser/.bashrc && \
    echo "export PS1='\[\e[1;31m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]# '" >> /root/.bashrc

# ২. কাস্টম ওয়েলকাম মেসেজ, 'mm', 'cc' এবং 'cs' ফাংশন তৈরি
RUN cat > /tmp/setup.sh <<'EOF'
# কাস্টম ওয়েলকাম মেসেজ (MOTD)
function custom_motd() {
    OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2)
    KERNEL_VERSION=$(uname -r)
    DATE=$(date +"%A, %d %B %Y, %T %Z")
    
    echo -e "\e[1;34m╭────────────────────────────────────────────────────────╮\e[0m"
    echo -e "\e[1;34m│ \e[1;37mWelcome to Phoenix Server\e[0m                              \e[1;34m│\e[0m"
    echo -e "\e[1;34m├────────────────────────────────────────────────────────┤\e[0m"
    echo -e "\e[1;34m│ \e[1;32mOS\e[0m     : ${OS_VERSION}"
    echo -e "\e[1;34m│ \e[1;32mKernel\e[0m : ${KERNEL_VERSION}"
    echo -e "\e[1;34m│ \e[1;32mDate\e[0m   : ${DATE}"
    echo -e "\e[1;34m╰────────────────────────────────────────────────────────╯\e[0m"
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
    RAM_MAX=$(cat /sys/fs/cgroup/memory.max 2>/dev/null); RAM_USED_KB=$(ps -U $USER -o rss | awk 'NR>1 {sum+=$1} END {if(sum=="") sum=0; print sum}'); RAM_USED_MB=$((RAM_USED_KB / 1024))
    if [[ "$RAM_MAX" =~ ^[0-9]+$ ]]; then RAM_MAX_MB=$((RAM_MAX / 1024 / 1024)); RAM_FREE_MB=$((RAM_MAX_MB - RAM_USED_MB)); R1="${RAM_MAX_MB}MB Max"; R2="${RAM_USED_MB}MB Used"; R3="${RAM_FREE_MB}MB Free"
    else R1="Unlimited"; R2="${RAM_USED_MB}MB Used"; R3="---"; fi
    CPU_USED=$(ps -U $USER -o %cpu | awk 'NR>1 {sum+=$1} END {if(sum=="") sum=0; print sum}'); C1="200% Max"; C2="${CPU_USED}% Used"; C3="---"
    D_MAX=$(df -h / | awk 'NR==2 {print $2}'); D_USED=$(df -h / | awk 'NR==2 {print $3}'); D_FREE=$(df -h / | awk 'NR==2 {print $4}'); D1="${D_MAX} Max"; D2="${D_USED} Used"; D3="${D_FREE} Free"
    HOME_USAGE=$(du -sh ~ 2>/dev/null | awk '{print $1}'); F1="---"; F2="${HOME_USAGE} Used"; F3="/home/$USER"
    print_row "❖" "RAM" "$R1" "$R2" "$R3"; print_row "⚙" "CPU" "$C1" "$C2" "$C3"; print_row "⛁" "DISK" "$D1" "$D2" "$D3"; print_row "▣" "FILES" "$F1" "$F2" "$F3"
    echo -e "${C_G}------------------------------------------------------------${C_R}\n"
}

# কানেক্ট ফাংশন (cc)
function cc() {
    if pgrep -x "tailscaled" > /dev/null
    then
        echo -e "\e[1;33mℹ Tailscale daemon is already running in background.\e[0m"
    else
        echo -e "\e[1;33m⌛ Starting Tailscale Daemon in background...\e[0m"
        sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &
        sleep 3
    fi

    echo -e "\e[1;36m"
    read -p "Enter Tailscale Auth Key: " TS_KEY
    echo -e "\e[0m"
    
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
    echo -e "   \e[1;33mcc\e[0m : Connect Tailscale"
    echo -e "   \e[1;31mcs\e[0m : Stop Tailscale\n"
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
