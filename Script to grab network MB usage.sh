#!/bin/bash

# Run netstat -i and capture the output
netstat_output=$(netstat -i)

# Extract the relevant lines (skip the first header line)
lines=$(echo "$netstat_output" | tail -n +2)

# Initialize counters for inbound and outbound packets
inbound_packets=0
outbound_packets=0

# Loop through each line of the netstat output
while read -r line; do
    # Parse the line to extract the inbound and outbound packet counts (RX-OK, TX-OK)
    rx_ok=$(echo "$line" | awk '{print $3}')
    tx_ok=$(echo "$line" | awk '{print $7}')
    
    # Check if both rx_ok and tx_ok are numeric
    if [[ "$rx_ok" =~ ^[0-9]+$ ]]; then
        inbound_packets=$((inbound_packets + rx_ok))
    fi
    if [[ "$tx_ok" =~ ^[0-9]+$ ]]; then
        outbound_packets=$((outbound_packets + tx_ok))
    fi
done <<< "$lines"

# Calculate the total packets (inbound + outbound)
total_packets=$((inbound_packets + outbound_packets))

# Approximate the packet size (standard Ethernet packet size is around 1500 bytes, for example)
packet_size_bytes=1500  # average Ethernet packet size in bytes

# Calculate total bytes (total packets * average packet size)
total_bytes=$((total_packets * packet_size_bytes))

# Convert total bytes to MB (1 MB = 1024 * 1024 bytes)
total_mb=$(echo "scale=2; $total_bytes / (1024 * 1024)" | bc)

# Output the result in a format that Jamf Pro can understand (only MB)
echo "<result>$total_mb</result>"
