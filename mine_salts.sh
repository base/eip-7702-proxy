#!/bin/bash
# mine_salts.sh

start_salt=10
batch_size=2000  # How many salts to try in each forge script run

if [ -z "$start_salt" ]; then
    start_salt=0
fi

while true; do
    echo "Trying salts from $start_salt to $((start_salt + batch_size))"
    
    # Run the forge script with our current salt range
    SALT_START=$start_salt SALT_BATCH=$batch_size forge script script/MineSalt.s.sol --ffi -v
    
    # Check if we found a solution (could check for a specific output)
    if [ $? -eq 0 ]; then
        echo "Found a matching salt! Check the output above."
        break
    fi
    
    # Move to next batch
    start_salt=$((start_salt + batch_size))
done