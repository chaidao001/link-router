"""Test macOS's real sender attribution, without changing default browsers."""
import os
from pathlib import Path
import re
import signal
import subprocess
import time

root = Path(__file__).resolve().parent.parent
router = root / 'build/Link Router.app'
sender = root / 'build/Router Test Sender.app'
output = root / 'build/integration-output.txt'
errors = root / 'build/integration-errors.txt'
output.write_text('')
errors.write_text('')
pid = None

def wait_for(pattern):
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        match = re.search(pattern, output.read_text())
        if match:
            return match
        time.sleep(0.1)
    raise RuntimeError('Integration test timed out. Output: ' + output.read_text() + '\n' + errors.read_text())

try:
    subprocess.run(['open', '-n', '-g', '--stdout', str(output), '--stderr', str(errors), str(router), '--args', '--diagnostic'], check=True)
    pid = int(wait_for(r'READY pid=(\d+)').group(1))
    subprocess.run(['open', '-n', '-g', '-W', str(sender), '--args', str(router)], check=True, timeout=20)
    wait_for(r'ROUTE source=local\.linkrouter\.test-sender browser=com\.google\.Chrome')
    print('Passed real macOS URL delivery: sender app correctly identified; Chrome selected; no browser opened.')
finally:
    if pid:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
