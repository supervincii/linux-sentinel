#!/usr/bin/env bash

# TODO
# Use awk for mathematical computations to allow floating point numbers
memory_usage_percentage() {
    # awk command explanation
    # awk has 3 special blocks:
    # BEGIN {...} -- runs before reading any input line
    # pattern-action pairs -- run for each matching line
    # END {...} -- runs after all the lines have been processed

    # In this case, we don't have a BEGIN block. The next lines with `/MemTotal:/` and `/MemAvailable:/` are processed.
    # It takes the line of that contains the regexp, then get the 2nd column (delimited by spaces), in this case,
    # to get the total and available memory.
    # The END block is then ran to compute the memory usage in percentage and print it as a floating point number.

    # SIDE NOTE
    # awk code must remain flush-left relative to the quotes because awk treats leading whitespaces as part of the script.
    # Indenting inside the quotes sometimes lead to readability issues or accidental whitespace matching.
    # Indenting inside actions (`{...}`) is however okay as awk ignores leading whitespaces in actions. It can also help
    # with readability.
    awk '
/MemTotal:/ { total = $2 }
/MemAvailable:/ { avail = $2 }
END {
    usage = (total - avail) * 100 / total
    printf "%.1f\n", usage
}
' /proc/meminfo
}

system_load_avg() {
    load_avg=$(grep -o '^[0-9.]\+' /proc/loadavg)
    echo "${load_avg}"
}

disk_io_performance() {
    # TODO
    # Get: avg read & write latency, utilization %
    filename="/proc/diskstats"

    read1=$(awk 'NR==1{print $4}' ${filename})
    read_throughput1=$(awk 'NR==1{print $6}' ${filename})
    write1=$(awk 'NR==1{print $8}' ${filename})
    write_throughput1=$(awk 'NR==1{print $10}' ${filename})

    sleep 30

    read2=$(awk 'NR==1{print $4}' ${filename})
    read_throughput2=$(awk 'NR==1{print $6}' ${filename})
    write2=$(awk 'NR==1{print $8}' ${filename})
    write_throughput2=$(awk 'NR==1{print $10}' ${filename})

    delta_read=$((read2 - read1))
    delta_write=$((write2 - write1))
    delta_read_throughput=$((read_throughput2 - read_throughput1))
    delta_write_throughput=$((write_throughput2 - write_throughput1))

    read_iops=$((delta_read / 30))
    write_iops=$((delta_write / 30))
    read_throughput=$((delta_read_throughput / 30))
    write_throughput=$((delta_write_throughput / 30))

    echo "$\tRead IOPS: ${read_iops}"
    echo "$\tWrite IOPS ${write_iops}"
    echo "$\tRead Throughput: ${read_throughput}"
    echo "$\tWrite Throughput: ${write_throughput}"
}

echo "Total RAM Usage: $(memory_usage_percentage)%"
echo "System Load Average: $(system_load_avg)"
