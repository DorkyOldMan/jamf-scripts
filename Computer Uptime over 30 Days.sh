#!/bin/bash


# Get system uptime in seconds
uptime_seconds=$(sysctl -n kern.boottime | awk -F'[ ,]' '{print $4}')

# Get current time in seconds since the last restart
current_time=$(date +%s)

# Calculate the time difference (current time - uptime start time)
time_diff=$((current_time - uptime_seconds))

# Define 30 days in seconds
thirty_days_seconds=$((30 * 24 * 60 * 60))

# Check if the system has been online for more than 30 days
if [ $time_diff -ge $thirty_days_seconds ]; then
	result="Yes"
else
	result="No"
fi

# Output the result for the Extension Attribute
echo "<result>$result</result>"
