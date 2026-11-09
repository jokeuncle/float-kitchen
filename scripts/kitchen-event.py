#!/usr/bin/env python3
"""Append an activity type to Float Kitchen. No prompt or output content needed."""
import argparse
import datetime
import json
from pathlib import Path
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('event', choices=['idle', 'reading', 'searching', 'cooking', 'testing', 'waiting', 'failed', 'served'])
parser.add_argument('--client', choices=['Codex', 'Claude', 'Local'], default='Local')
parser.add_argument('--tool', default='')
parser.add_argument('--label', default='')
args = parser.parse_args()
destination = Path.home() / 'Library/Application Support/FloatKitchen/events.jsonl'
destination.parent.mkdir(parents=True, exist_ok=True)
destination.touch(mode=0o600, exist_ok=True)
row = {'id': str(uuid.uuid4()), 'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'client': args.client, 'event': args.event, 'tool': args.tool[:60], 'label': args.label[:90]}
with destination.open('a', encoding='utf-8') as stream:
    stream.write(json.dumps(row) + '\n')
print('Kitchen event:', args.client, args.event)
