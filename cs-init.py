#!/usr/bin/env python3

import os
import time
import subprocess

DEFAULT_WORKER = "DBRM_Worker1"
DEFAULT_WAIT = "3"
DEFAULT_RETRY = "3"

PROCS = {
    "workernode": [],
    "controllernode": [],
    "PrimProc": [],
    "WriteEngineServer": [],
    "DMLProc": [],
    "DDLProc": [],
}

trace = {}


def start(name, cmd):
    """Start a process"""
    print(f"Starting {name}: {cmd}")
    p = subprocess.Popen(cmd)
    time.sleep(DEFAULT_WAIT)
    if p.poll() is None:
        print(f"Started {name}")
        return p

    print(f"Failed to start {name}.")
    return None


def monitor():
    """Monitor and restart a process"""
    for i, j in PROCS.items():
        p = trace.get(i)
        if not p and p.poll() is not None:
            if p:
                print(f"Resarting {i}: {j}")
            else:
                print(f"Starting {i}: {j}")

            trace[i] = start_process(i, j)


def main():
    """Main"""
    for i, j in PROCS.items():
        p = start(i, j)
        if p is not None:
            trace[i] = p
        else:
            print(f"ERROR failed to start {i}: {j}")
            return

    while True:
        monitor()
        time.sleep(DEFAULT_RETRY)


if __name__ == "__main__":
    main()
