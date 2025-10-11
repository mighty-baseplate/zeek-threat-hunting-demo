#!/bin/bash

# Real-time SSH brute-force alert and blocker
ZEEK_LOG="/opt/zeek/logs/current/ssh.log"
CHECK_INTERVAL=5  # Check every 5 seconds
THRESHOLD=10      # Alert after 10 failed attempts in 30 seconds
WINDOW=30         # Time window in seconds

echo "[$(date)] SSH Alert Monitor Started"
echo "Watching: $ZEEK_LOG"
echo "Threshold: $THRESHOLD failed logins in $WINDOW seconds"
echo "---"

# Keep track of last processed line
LAST_LINE=0

while true; do
    # Get current line count
    CURRENT_LINE=$(wc -l < "$ZEEK_LOG" 2>/dev/null || echo 0)
    
    # If new lines appeared, process them
    if [ "$CURRENT_LINE" -gt "$LAST_LINE" ]; then
        # Get only new lines
        NEW_LINES=$((CURRENT_LINE - LAST_LINE))
        
        # Extract failed logins from new lines (last N lines)
        tail -n "$NEW_LINES" "$ZEEK_LOG" 2>/dev/null | while read -r line; do
            # Check if line contains auth_success: false (failed login)
            if echo "$line" | grep -q '"auth_success":false'; then
                # Extract attacker IP
                ATTACKER_IP=$(echo "$line" | grep -oP '"id\.orig_h":"\K[^"]+')
                TIMESTAMP=$(echo "$line" | grep -oP '"ts":\K[0-9.]+')
                
                if [ -n "$ATTACKER_IP" ]; then
                    echo "[$(date)] Failed SSH login from: $ATTACKER_IP"
                    
                    # Count failed attempts from this IP in the last 30 seconds
                    CURRENT_TIME=$(date +%s)
                    WINDOW_START=$((CURRENT_TIME - WINDOW))
                    
                    # Count recent failures from this IP
                    FAILURE_COUNT=$(tail -n 500 "$ZEEK_LOG" | \
                        grep '"auth_success":false' | \
                        grep "\"id.orig_h\":\"$ATTACKER_IP\"" | \
                        grep -oP '"ts":\K[0-9.]+' | \
                        awk -v window="$WINDOW_START" '{if ($1 >= window) count++} END {print count+0}')
                    
                    echo "  -> Total failures from $ATTACKER_IP in last ${WINDOW}s: $FAILURE_COUNT"
                    
                    # If threshold exceeded, show alert
                    if [ "$FAILURE_COUNT" -ge "$THRESHOLD" ]; then
                        # Check if already blocked
                        if sudo iptables -L INPUT -n | grep -q "$ATTACKER_IP"; then
                            echo "  -> Already blocked: $ATTACKER_IP"
                        else
                            echo ""
                            echo "!!! BRUTE-FORCE DETECTED !!!"
                            echo "!!! $FAILURE_COUNT failed attempts from $ATTACKER_IP !!!"
                            
                            # Show GUI alert (if DISPLAY is set)
                            if [ -n "$DISPLAY" ]; then
                                zenity --question \
                                    --title="SSH Brute-Force Detected!" \
                                    --text="Suspicious brute-force attack detected!\n\nAttacker IP: $ATTACKER_IP\nFailed attempts: $FAILURE_COUNT in ${WINDOW} seconds\n\nBlock this IP with iptables?" \
                                    --width=400 2>/dev/null
                                
                                if [ $? -eq 0 ]; then
                                    # User clicked Yes - block the IP
                                    echo "  -> User chose to BLOCK $ATTACKER_IP"
                                    sudo iptables -A INPUT -s "$ATTACKER_IP" -j DROP
                                    echo "  -> BLOCKED: $ATTACKER_IP"
                                    
                                    # Log the block
                                    echo "[$(date)] BLOCKED IP: $ATTACKER_IP (iptables)" >> ~/blocked_ips.log
                                else
                                    echo "  -> User chose NOT to block $ATTACKER_IP"
                                fi
                            else
                                # No GUI - just log
                                echo "  -> (No display available for GUI alert)"
                            fi
                            echo ""
                        fi
                    fi
                fi
            fi
        done
        
        # Update last processed line
        LAST_LINE=$CURRENT_LINE
    fi
    
    # Wait before next check
    sleep "$CHECK_INTERVAL"
done