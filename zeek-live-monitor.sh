#!/bin/bash

# Real-time network monitor for Zeek logs

LOG_DIR="/opt/zeek/spool/zeek"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Function to format timestamp
format_time() {
    date -d "@$1" "+%H:%M:%S" 2>/dev/null || echo "$1"
}

# Print header
print_header() {
    clear
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║       ZEEK NETWORK SECURITY MONITOR - LIVE ATTACK DETECTION              ║${NC}"
    echo -e "${BOLD}${CYAN}║                    Monitoring: enp0s3                                    ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show SSH attacks with highlighting
monitor_ssh_attacks() {
    echo -e "${BOLD}${RED}🚨 SSH BRUTE-FORCE ATTEMPTS DETECTED 🚨${NC}\n"
    echo -e "${BOLD}Time      Attacker IP        → Target           Client              Status${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────────"
    
    if [[ -f "$LOG_DIR/ssh.log" ]]; then
        sudo tail -f "$LOG_DIR/ssh.log" 2>/dev/null | while IFS= read -r line; do
            if [[ $line == "{"* ]]; then
                ts=$(echo "$line" | jq -r '.ts' 2>/dev/null)
                src=$(echo "$line" | jq -r '."id.orig_h"' 2>/dev/null)
                dst=$(echo "$line" | jq -r '."id.resp_h"' 2>/dev/null)
                client=$(echo "$line" | jq -r '.client' 2>/dev/null)
                
                time_fmt=$(format_time "$ts")
                
                # Highlight attacks from specific IP (your Kali machine)
                if [[ $src == "192.168.1.12" ]]; then
                    printf "${WHITE}%-9s${NC} ${RED}${BOLD}%-18s${NC} ${WHITE}→${NC} ${MAGENTA}%-16s${NC} ${CYAN}%-20s${NC} ${RED}⚠️  ATTACK${NC}\n" \
                        "$time_fmt" "$src" "$dst" "$client"
                else
                    printf "${WHITE}%-9s${NC} ${CYAN}%-18s${NC} ${WHITE}→${NC} ${MAGENTA}%-16s${NC} ${CYAN}%-20s${NC} ${GREEN}✓ Normal${NC}\n" \
                        "$time_fmt" "$src" "$dst" "$client"
                fi
            fi
        done
    else
        echo -e "${YELLOW}Waiting for SSH traffic... (No ssh.log yet)${NC}"
        sleep 2
        monitor_ssh_attacks
    fi
}

# Monitor all connections with color coding
monitor_connections() {
    echo -e "${BOLD}${GREEN}📡 NETWORK CONNECTIONS${NC}\n"
    echo -e "${BOLD}Time      Source             → Destination        Port   Proto  State${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────────"
    
    sudo tail -f "$LOG_DIR/conn.log" 2>/dev/null | while IFS= read -r line; do
        if [[ $line == "{"* ]]; then
            ts=$(echo "$line" | jq -r '.ts' 2>/dev/null)
            src=$(echo "$line" | jq -r '."id.orig_h"' 2>/dev/null)
            dst=$(echo "$line" | jq -r '."id.resp_h"' 2>/dev/null)
            port=$(echo "$line" | jq -r '."id.resp_p"' 2>/dev/null)
            proto=$(echo "$line" | jq -r '.proto' 2>/dev/null)
            state=$(echo "$line" | jq -r '.conn_state' 2>/dev/null)
            
            time_fmt=$(format_time "$ts")
            
            # Color code SSH connections (port 22) in RED
            if [[ $port == "22" ]]; then
                printf "${WHITE}%-9s${NC} ${RED}${BOLD}%-18s${NC} ${WHITE}→${NC} ${MAGENTA}%-18s${NC} ${RED}%-6s${NC} %-6s ${RED}%s${NC}\n" \
                    "$time_fmt" "$src" "$dst" "$port" "$proto" "$state"
            else
                case $state in
                    "SF"|"SH") state_color="${GREEN}" ;;
                    "S0"|"REJ") state_color="${YELLOW}" ;;
                    *) state_color="${WHITE}" ;;
                esac
                printf "${WHITE}%-9s${NC} ${CYAN}%-18s${NC} ${WHITE}→${NC} ${MAGENTA}%-18s${NC} ${YELLOW}%-6s${NC} %-6s ${state_color}%s${NC}\n" \
                    "$time_fmt" "$src" "$dst" "$port" "$proto" "$state"
            fi
        fi
    done
}

# Split-screen view: SSH attacks + all connections
monitor_combined() {
    print_header
    
    # Split screen effect - show both SSH attacks and connections
    (
        echo -e "${BOLD}${RED}🚨 SSH ATTACKS (Port 22)${NC}"
        echo "─────────────────────────────────────────────────────────────────────────"
        
        if [[ -f "$LOG_DIR/ssh.log" ]]; then
            sudo tail -f "$LOG_DIR/ssh.log" 2>/dev/null | while IFS= read -r line; do
                if [[ $line == "{"* ]]; then
                    ts=$(echo "$line" | jq -r '.ts' 2>/dev/null)
                    src=$(echo "$line" | jq -r '."id.orig_h"' 2>/dev/null)
                    dst=$(echo "$line" | jq -r '."id.resp_h"' 2>/dev/null)
                    time_fmt=$(format_time "$ts")
                    printf "${WHITE}[%s]${NC} ${RED}ATTACK:${NC} ${RED}%s${NC} → ${MAGENTA}%s${NC}\n" \
                        "$time_fmt" "$src" "$dst"
                fi
            done
        fi
    ) &
    
    SSH_PID=$!
    
    echo ""
    echo -e "${BOLD}${GREEN}📊 ALL NETWORK ACTIVITY${NC}"
    echo "─────────────────────────────────────────────────────────────────────────"
    
    sudo tail -f "$LOG_DIR/conn.log" 2>/dev/null | while IFS= read -r line; do
        if [[ $line == "{"* ]]; then
            ts=$(echo "$line" | jq -r '.ts' 2>/dev/null)
            src=$(echo "$line" | jq -r '."id.orig_h"' 2>/dev/null)
            dst=$(echo "$line" | jq -r '."id.resp_h"' 2>/dev/null)
            port=$(echo "$line" | jq -r '."id.resp_p"' 2>/dev/null)
            time_fmt=$(format_time "$ts")
            
            if [[ $port == "22" ]]; then
                printf "${WHITE}[%s]${NC} ${RED}SSH:${NC} %s → %s:${RED}%s${NC}\n" \
                    "$time_fmt" "$src" "$dst" "$port"
            else
                printf "${WHITE}[%s]${NC} %s → %s:${YELLOW}%s${NC}\n" \
                    "$time_fmt" "$src" "$dst" "$port"
            fi
        fi
    done
    
    kill $SSH_PID 2>/dev/null
}

# Menu
MODE="${1:-combined}"

case $MODE in
    ssh)
        print_header
        monitor_ssh_attacks
        ;;
    conn)
        print_header
        monitor_connections
        ;;
    combined|*)
        monitor_combined
        ;;
esac