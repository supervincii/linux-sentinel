#!/usr/bin/env bash

# TODO
# Use awk have floating point values on the current computations
memory_usage_percentage() {
    total_memory=$(grep -i 'memtotal' /proc/meminfo | grep -o '[[:digit:]]\+')
    available_memory=$(grep -i 'memavailable' /proc/meminfo | grep -o '[[:digit:]]\+')
    memory_usage=$(( total_memory - available_memory))
    usage_percentage=$(( memory_usage * 100 / $total_memory))
    echo "${usage_percentage}"
}

cpu_load_avg() {
    load_avg=$(grep -o '^[0-9.]\+' /proc/loadavg)
    echo "${load_avg}"
}

echo "Total RAM Usage: $(memory_usage_percentage)%"
echo "CPU Load Average: $(cpu_load_avg)"
