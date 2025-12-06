#!/usr/bin/env bash

memory_usage_percentage() {
    total_memory=$(grep -i 'memtotal' /proc/meminfo | grep -o '[[:digit:]]\+')
    available_memory=$(grep -i 'memavailable' /proc/meminfo | grep -o '[[:digit:]]\+')
    memory_usage=$(( total_memory - available_memory))
    usage_percentage=$(( memory_usage * 100 / $total_memory))
    echo "${usage_percentage}"
}

echo "Total RAM Usage: $(memory_usage_percentage)%"
