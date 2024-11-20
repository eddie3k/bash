#!/bin/bash

# This script checks if Veeam Backup Agent is installed on your servers,
# if the Veeam service is running, and when the last backup was taken.
# It assumes that the user has passwordless sudo privileges on the remote hosts.

# Extract Hostnames from SSH Config
hosts=$(grep "^Host " ~/.ssh/config | awk '{print $2}')

# Create a temporary file to store outputs
output_file=$(mktemp)

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Loop Through Hosts
for host in $hosts
do
    (
        ssh_command="ssh -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=5 \
        -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $host"

        # Test SSH connection
        $ssh_command "echo 'SSH Connection Established'" &> /dev/null
        if [ $? -ne 0 ]; then
            # SSH failed
            echo -e "$host: ${RED}SSH Connection Failed${NC}" >> "$output_file"
            exit 1
        fi

        # Check if veeamconfig exists
        $ssh_command "sudo which veeamconfig" &> /dev/null
        if [ $? -eq 0 ]; then
            # Veeam is installed

            # Initialize variables
            veeam_running=false
            last_backup_info="${YELLOW}No backup information available${NC}"

            # Check if Veeam service is running using systemctl
            service_status=$($ssh_command "sudo systemctl is-active veeamservice" 2>/dev/null)
            if [ "$service_status" == "active" ]; then
                veeam_running=true
            fi

            # Get last successful backup session
            # Retrieve session list, skip headers and the last line
            session_list=$($ssh_command "sudo veeamconfig session list 2>/dev/null | tail -n +3 | head -n -1")

            if [ -n "$session_list" ]; then
                # Reverse the session list to start from the latest session
                latest_sessions=$(echo "$session_list" | tac)

                # Find the latest successful backup
                while IFS= read -r line; do
                    # Skip empty lines
                    [ -z "$line" ] && continue

                    # Get the State (4th field) and Start Time (5th field)
                    state=$(echo "$line" | awk '{print $4}')
                    start_time=$(echo "$line" | awk '{print $5, $6}')

                    if [ "$state" == "Success" ]; then
                        last_backup_info="Last successful backup: $start_time"
                        break
                    fi
                done <<< "$latest_sessions"

                # If no successful backup was found
                if [ "$last_backup_info" == "${YELLOW}No backup information available${NC}" ]; then
                    last_backup_info="${YELLOW}No successful backups found${NC}"
                fi
            else
                last_backup_info="${YELLOW}No backup sessions found${NC}"
            fi

            # Output
            if $veeam_running; then
                echo -e "$host: ${GREEN}Veeam is installed and running${NC}" >> "$output_file"
            else
                echo -e "$host: ${YELLOW}Veeam is installed but not running${NC}" >> "$output_file"
            fi

            echo -e "$host: $last_backup_info" >> "$output_file"

        else
            # Veeam not installed
            echo -e "$host: ${RED}Veeam is not installed${NC}" >> "$output_file"
        fi

    ) &
done

# Wait for All Background SSH Calls to Complete
wait

# Output the results
cat "$output_file"

# Remove the temporary file
rm -f "$output_file"

echo "All hosts checked."
