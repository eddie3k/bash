#!/bin/bash

# Check if the username is passed as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 username"
  exit 1
fi

USERNAME=$1

# Find all groups starting with 'www.' and extract group names into an array
mapfile -t GROUPS_ARRAY < <(getent group | grep '^www\.' | cut -d: -f1)

# Debug: Output found groups
echo "Debug: Found groups - [${GROUPS_ARRAY[@]}]"

# Check if there are any groups that start with 'www.'
if [ ${#GROUPS_ARRAY[@]} -eq 0 ]; then
  echo "No groups starting with 'www.' found."
  exit 1
fi

# Add the user to each group in the array
for group in "${GROUPS_ARRAY[@]}"; do
  echo "Adding user $USERNAME to group: $group"
  sudo usermod -aG "$group" "$USERNAME"

  # Check if usermod was successful
  if [ $? -ne 0 ]; then
    echo "Failed to add $USERNAME to group: $group"
    exit 1
  fi
done

echo "User $USERNAME has been successfully added to the groups: ${GROUPS_ARRAY[@]}"
