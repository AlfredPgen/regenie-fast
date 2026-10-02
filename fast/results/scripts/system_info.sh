#!/bin/bash
# Prints the OS, kernel, logical CPUs, CPU model, memory and data file system of the WSL machine used for all tests and benchmarks.
. /etc/os-release; echo "$PRETTY_NAME"; uname -r; nproc; grep -m1 "model name" /proc/cpuinfo; free -g | head -2; df -T ~/rgprof/data | tail -1
