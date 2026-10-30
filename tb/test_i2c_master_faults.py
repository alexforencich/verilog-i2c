#!/usr/bin/env python3
"""Run standalone Icarus tests for opt-in NACK termination and control timing."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as directory:
    for stop_on_nack in (0, 1):
        output = str(Path(directory) / 'faults.vvp')
        subprocess.run([os.environ.get('IVERILOG', 'iverilog'), '-g2012',
                        '-s', 'test_i2c_master_faults',
                        '-Ptest_i2c_master_faults.STOP_ON_NACK=' + str(stop_on_nack),
                        '-o', output, str(root / 'rtl/i2c_master.v'),
                        str(root / 'tb/test_i2c_master_faults.sv')], check=True)
        subprocess.run([os.environ.get('VVP', 'vvp'), output], check=True, timeout=30)
