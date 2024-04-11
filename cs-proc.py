#!/usr/bin/env python3

import os
import subprocess as sp

DEFAULT_WORKER = "DBRM_Worker1"
DEFAULT_WAIT = "3"
DEFAULT_RETRY = "3"

PROCS = {
    "workernode": {},
    "controllernode": {},
    "PrimProc": {},
    "WriteEngineServer": {},
    "DMLProc": {},
    "DDLProc": {},
}


def run(cmd, wait, retry):
    pass


def main():
    worker = os.getenv("DBRM_WORKER", DEFAULT_WORKER)
    wait = os.getenv("CS_INIT_WAIT", DEFAULT_WAIT)
    wait = os.getenv("CS_INIT_RETRY", DEFAULT_RETRY)


if __name__ == "__main__":
    main()
