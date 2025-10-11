#!/bin/bash

# Zeek Log Viewer - Clean formatted output for demonstrations
# Usage: ./zeek-log-viewer.sh [conn|ssh|dns|http|all]

LOG_DIR="/opt/zeek/spool/zeek"
LOG_TYPE="${1:-all}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Clear screen and show header
clear
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║           ZEEK NETWORK SECURITY MONITOR - LIVE LOGS                ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to format timestamp
format_time() {
    local ts=$1
    date -d "@$ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$ts"
}

# Function to display connection logs
show_conn_logs() {
    echo -e "${BOLD}${GREEN}[CONNECTION LOGS]${NC}"
    echo -e "${BOLD}Time                  Source IP          -> Destination IP       Port   Protocol  State${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────────────────"
    
    sudo tail -n 20 "$LOG_DIR/conn.log" 2>/dev/null | while IFS= read -r line; do
        if [[ $line == "{"* ]]; then
            ts=$(echo "$line" | jq -r '.ts' 2>/dev/null)
            src=$(echo "$line" | jq -r '."id.orig_h"' 2>/dev/null)
            dst=$(echo "$line" | jq -r '."id.resp_h"' 2>/dev/null)
            port=$(echo "$line" | jq -r '."id.resp_p"' 2>/dev/null)
            proto=$(echo "$line" | jq -r '.proto' 2>/dev/null)
            state=$(echo "$line" | jq -r '.conn_state' 2>/dev/null)
            
            time_fmt=$(format_time "$ts")
            
            # Color code by state
            case $state in
                "SF"|"SH") state_color="${GREEN}" ;;
                "S0"|"REJ") state_color="${RED}" ;;
                *) state_color="${YELLOW}" ;;
            esac
            
            printf "${WHITE}%-20s${NC} ${CYAN}%-18s${NC} -> ${MAGENTA}%-18s${NC} ${YELLOW}%-6s${NC} %-8s ${state_color}%s${NC}\n" \
                "$time_fmt" "$src" "$dst" "$port" "$proto" "$state"
        fi
    done
    echo ""
}

# Function to display SSH logs
show_ssh_logs() {
    echo -e "${BOLD}${RED}[SSH AUTHENTICATION ATTEMPTS]${NC}"
    echo -e "${BOLD}Time                  Source IP          -> Target             Client Version${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────────────────"
    
    if [[ -f "$LOG_DIR/ssh.log" ]]; then
        sudo tail -n 20 "$LOG_DIR/ssh.log" 2>/dev/null | while IFS= read -r line; do
            if [[ $line == "{"* ]]; then
                ts=$(echo "$line" | jq -r '.ts' 2>/dev/null)
                src=$(echo "$line" | jq -r '."id.orig_h"' 2>/dev/null)
                dst=$(echo "$line" | jq -r '."id.resp_h"' 2>/dev/null)
                client=$(echo "$line" | jq -r '.client' 2>/dev/null)
                auth_attempts=$(echo "$line" | jq -r '.auth_attempts' 2>/dev/null)
                
                time_fmt=$(format_time "$ts")
                
                printf "${WHITE}%-20s${NC} ${RED}%-18s${NC} -> ${MAGENTA}%-18s${NC} ${CYAN}%s${NC}\n" \
                    "$time_fmt" "$src" "$dst" "$client"
            fi
        done
    else
        echo -e "${YELLOW}No SSH logs available yet. Generate SSH traffic to see logs here.${NC}"
    fi
    echo ""
}

# Function to display DNS logs
show_dns_logs() {
    echo -e "${BOLD}${BLUE}[DNS QUERIES]${NC}"
    echo -e "${BOLD}Time                  Source IP          Query Domain                              Type${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────────────────"
    
    if [[ -f "$LOG_DIR/dns.log" ]]; then
        sudo tail -n 15 "$LOG_DIR/dns.log" 2>/dev/null | while IFS= read -r line; do
            if [[ $line == "{"* ]]; then
                ts=$(echo "$line" | jq -r '.ts' 2>/dev/null)
                src=$(echo "$line" | jq -r '."id.orig_h"' 2>/dev/null)
                query=$(echo "$line" | jq -r '.query' 2>/dev/null)
                qtype=$(echo "$line" | jq -r '.qtype_name' 2>/dev/null)
                
                time_fmt=$(format_time "$ts")
                
                printf "${WHITE}%-20s${NC} ${CYAN}%-18s${NC} ${GREEN}%-40s${NC} ${YELLOW}%s${NC}\n" \
                    "$time_fmt" "$src" "$query" "$qtype"
            fi
        done
    else
        echo -e "${YELLOW}No DNS logs available.${NC}"
    fi
    echo ""
}

# Function to display HTTP logs
show_http_logs() {
    echo -e "${BOLD}${MAGENTA}[HTTP TRAFFIC]${NC}"
    echo -e "${BOLD}Time                  Source -> Host                              Method  URI${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────────────────"
    
    if [[ -f "$LOG_DIR/http.log" ]]; then
        sudo tail -n 15 "$LOG_DIR/http.log" 2>/dev/null | while IFS= read -r line; do
            if [[ $line == "{"* ]]; then
                ts=$(echo "$line" | jq -r '.ts' 2>/dev/null)
                src=$(echo "$line" | jq -r '."id.orig_h"' 2>/dev/null)
                host=$(echo "$line" | jq -r '.host' 2>/dev/null)
                method=$(echo "$line" | jq -r '.method' 2>/dev/null)
                uri=$(echo "$line" | jq -r '.uri' 2>/dev/null | cut -c1-30)
                
                time_fmt=$(format_time "$ts")
                
                printf "${WHITE}%-20s${NC} ${CYAN}%-6s${NC} -> ${GREEN}%-35s${NC} ${YELLOW}%-7s${NC} ${BLUE}%s${NC}\n" \
                    "$time_fmt" "$src" "$host" "$method" "$uri"
            fi
        done
    else
        echo -e "${YELLOW}No HTTP logs available.${NC}"
    fi
    echo ""
}

# Main logic
case $LOG_TYPE in
    conn)
        show_conn_logs
        ;;
    ssh)
        show_ssh_logs
        ;;
    dns)
        show_dns_logs
        ;;
    http)
        show_http_logs
        ;;
    all|*)
        show_ssh_logs
        show_conn_logs
        show_dns_logs
        ;;
esac

echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}TIP: Run with -f flag to follow logs in real-time${NC}"
echo -e "${WHITE}Usage: sudo ./zeek-log-viewer.sh [conn|ssh|dns|http|all]${NC}"