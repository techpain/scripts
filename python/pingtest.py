#!/usr/bin/python

# Import Modules
import os
import platform
import fileinput
import datetime
import sys

# Define Ping Function
def ping(line):
    # Returns True if host responds to a ping request
    #
    import os, platform

    # Ping parameters as function of OS
    ping_str = "-n 1" if  platform.system().lower()=="windows" else "-c 1 -W 1"

    # Ping
    #return os.system("ping " + ping_str + " " + line) == 0
    return os.system("ping " + ping_str + " " + line)

# Create Report File
# Use "a" instead of "w" to append to file
f = open("report.txt", "w")

# Tell Standard Output To Write To Your File
sys.stdout = f

# Ping Each Entry In File
for line in fileinput.input():
    p = ping(line)

    # Check If Up Or Down
    if p == 0:
        print(line, "UP")
    else:
        print(line, "DOWN")

    #print(line, p)

# Close Report File
f.close()
