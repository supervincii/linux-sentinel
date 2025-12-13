#!/usr/bin/env bash

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
    load_avg=$(cut -d ' ' -f 1 /proc/loadavg)
    printf "%.2f\n" "${load_avg}"
}

disk_io_performance() {
    # Contents of /proc/diskstats
    # 1. major number - block device identifier used by the kernel to identify the driver type
    # 2. minor number - identifier for a specific disk/partition under the major class
    # 3. device name
    # 4. reads completed successfully - total # of read I/O completed
    # 5. reads merged - # of read requests the kernel merged because they were adjacent
    # 6. total # of sectors read - usually sector size is 512 bytes (read sector size by `lsblk -o NAME,LOG-SEC,PHY-SEC`)
    # 7. time spent reading (ms) - cumulative time spent by all read operations
    # 8. writes completed successfully - total # of write I/O completed
    # 9. writes merged - # of write requests the kernel merged because they were adjacent
    # 10. total # of sectors written - usually sector size is 512 bytes (but not guaranteed)
    # 11. time spent writing (ms) - cumulative time spent writing
    # 12. I/Os currently in progress - # of read/write operations running at the moment
    # 13. time spent doing I/O (ms) - total time the device spent performing any I/O
    # 14. weighted time spent doing I/O (ms) - (queue_depth * time) (e.g. 4 I/Os in progress for 1s = 4000ms)
    # 15-17. discard stats - TRIM operations on SSD
    # 18-19. flush stats - for write cache flush (fsync operations)
    disk_name="nvme0n1"
    sector_size=$(cat /sys/block/${disk_name}/queue/logical_block_size)
    interval=15

    # Read first snapshot of disk stats
    # `read` takes in the input of the awk command and assign it to variables
    # This is done by doing string redirection (`<<<`) which takes the output from the awk command, which is
    # a single line of values separated by whitespaces, and assigning it tothe variable listed.
    # The `-r` flag ensures that backslashes aren't interpreted as escape characters. It is best practice to use the `-r`
    # flag with the `read` command.
    read -r reads1 read_sectors1 reads_ms1 writes1 write_sectors1 writes_ms1 io_ms1 <<< \
         "$(awk -v d="${disk_name}" '$3==d {print $4, $6, $7, $8, $10, $11, $13}' /proc/diskstats)"

    # TODO
    # Sleep won't be used anymore when we log the metrics to a file.
    # It will capture a single snapshot, then read the previous file to perform calculation.
    sleep "${interval}"

    read -r reads2 read_sectors2 reads_ms2 writes2 write_sectors2 writes_ms2 io_ms2 <<< \
         "$(awk -v d="${disk_name}" '$3==d {print $4, $6, $7, $8, $10, $11, $13}' /proc/diskstats)"

    awk -v interval="${interval}" -v sector_size="${sector_size}" \
        -v r1="${reads1}" -v r2="${reads2}" \
        -v sr1="${read_sectors1}" -v sr2="${read_sectors2}" \
        -v rt1="${reads_ms1}" -v rt2="${reads_ms2}" \
        -v w1="${writes1}" -v w2="${writes2}" \
        -v wr1="${write_sectors1}" -v wr2="${write_sectors2}" \
        -v wt1="${writes_ms1}" -v wt2="${writes_ms2}" \
        -v iot1="${io_ms1}" -v iot2="${io_ms2}" '
BEGIN {
      delta_read = r2 - r1
      delta_sectors_read = sr2 - sr1
      delta_read_time = rt2 - rt1
      delta_write = w2 - w1
      delta_sectors_write = wr2 - wr1
      delta_write_time = wt2 - wt1
      delta_io_time = iot2 - iot1

      read_iops = delta_read / interval
      write_iops = delta_write / interval
      read_throughput = (delta_sectors_read * sector_size) / interval
      write_throughput = (delta_sectors_write * sector_size) / interval
      avg_read_latency = (delta_read > 0 ? delta_read_time / delta_read : 0)
      avg_write_latency = (delta_write > 0 ? delta_write_time / delta_write : 0)
      disk_utilization = (delta_io_time / (interval * 1000)) * 100

      printf "Read IOPS: %.2f IO/s\n", read_iops
      printf "Write IOPS: %.2f IO/s\n", write_iops
      printf "Read Throughput: %.2f bytes/s\n", read_throughput
      printf "Write Throughput: %.2f bytes/s\n", write_throughput
      printf "Average Read Latency: %.2f ms\n", avg_read_latency
      printf "Average Write Latency: %.2f ms\n", avg_write_latency
      printf "Disk Utilization: %.2f %%\n", disk_utilization
}'
}

network_metrics() {
    # Contents of /proc/diskstats
    # 1. interface - name of the network interface
    # 2. bytes - receive - total # of bytes received
    # 3. packets - receive - total # of packets received
    # 4. errs - receive - total # of receive errors detected by the device driver
    # 5. drop - receive - total # of packets dropped by the device driver
    # 6. fifo - receive - # of FIFO buffer errors
    # 7. frame - recieve - # of packet framing errors
    # 8. compressed - receive - # of compressed packets received
    # 9. multicast - receive - # of multicast packets received
    # 10. bytes - transmit - total # of bytes transmitted
    # 11. packets - transmit - total # of packets transmitted
    # 12. errs - transmit - total # of transmit errors detected by the device driver
    # 13. drop - transmit - total # of packets dropped by the device driver
    # 14. fifo - transmit - # of FIFO buffer errors
    # 15. colls - transmit - # of collisions detected on the interface
    # 16. carrier - recieve - # of carrier losses detected by the device driver
    # 17. compressed - transmit - # of compressed packets transmitted
    interface="enp1s0"
    interval=15

    # awk here checks if the regexp matches (~) `^enp1s0:` with the first value ($1)
    read -r receive_bytes1 receive_errs1 receive_drops1 transmit_bytes1 transmit_errs1 transmit_drops1 <<< \
         "$(awk -v i="${interface}" '$1 ~ "^" i ":" {print $2, $4, $5, $10, $12, $13}' /proc/net/dev)"

    sleep ${interval}

    read -r receive_bytes2 receive_errs2 receive_drops2 transmit_bytes2 transmit_errs2 transmit_drops2 <<< \
         "$(awk -v i="${interface}" '$1 ~ "^" i ":" {print $2, $4, $5, $10, $12, $13}' /proc/net/dev)"

    awk -v receive_bytes1="${receive_bytes1}" -v receive_errs1="${receive_errs1}" -v receive_drops1="${receive_drops1}" \
        -v receive_bytes2="${receive_bytes2}" -v receive_errs2="${receive_errs2}" -v receive_drops2="${receive_drops2}" \
        -v transmit_bytes1="${transmit_bytes1}" -v transmit_errs1="${transmit_errs1}" -v transmit_drops1="${transmit_drops1}" \
        -v transmit_bytes2="${transmit_bytes2}" -v transmit_errs2="${transmit_errs2}" -v transmit_drops2="${transmit_drops2}" \
        -v interval="${interval}" '
BEGIN {
      delta_receive_bytes = receive_bytes2 - receive_bytes1
      delta_receive_errs = receive_errs2 - receive_errs1
      delta_receive_drops = receive_drops2 - receive_drops1
      delta_transmit_bytes = transmit_bytes2 - transmit_bytes1
      delta_transmit_errs = transmit_errs2 - transmit_errs1
      delta_transmit_drops = transmit_drops2 - transmit_drops1

      receive_throughput = delta_receive_bytes / interval
      receive_err_rate = delta_receive_errs / interval
      receive_drop_rate = delta_receive_drops / interval
      transmit_throughput = delta_transmit_bytes / interval
      transmit_err_rate = delta_transmit_errs / interval
      transmit_drop_rate = delta_transmit_drops / interval

      printf "Receive Throughput: %.2f bytes/s\n", receive_throughput
      printf "Receive Error Rate: %.2f errors/s\n", receive_err_rate
      printf "Receive Drop Rate: %.2f drops/s\n", receive_drop_rate
      printf "Transmit Throughput: %.2f bytes/s\n", transmit_throughput
      printf "Transmit Error Rate: %.2f errors/s\n", transmit_err_rate
      printf "Transmit Drop Rate: %.2f drops/s\n", transmit_drop_rate
}'
}

echo "Total RAM Usage: $(memory_usage_percentage)%"
echo "System Load Average: $(system_load_avg)"
echo "Disk I/O Performance: "
disk_io_performance
echo "Network Performance: "
network_metrics
