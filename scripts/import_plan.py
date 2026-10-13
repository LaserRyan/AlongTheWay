"""Import the attached PDF's layout extraction, including wrapped entries."""
import json
import pathlib
import re

source = pathlib.Path('plan-complete.txt').read_text(encoding='utf-8')
readings = {}
columns = [0, 37, 59, 97, 1000]
previous = {}
for line in source.splitlines():
    if line.startswith('171. '):
        columns = [0, 41, 79, 113, 1000]
        previous = {}
    for i in range(4):
        cell = line[columns[i]:columns[i+1]].strip()
        match = re.match(r'^(\d+)\.\s+(.+)$', cell)
        if match:
            day = int(match[1])
            if day in readings:
                raise ValueError(f'Duplicate day {day}')
            readings[day] = match[2]
            previous[i] = day
        elif cell and i in previous and re.match(r'^(?:Psalm|2 Chronicles)', cell):
            readings[previous[i]] += ' ' + cell
assert sorted(readings) == list(range(1, 366)), f'Missing readings: {set(range(1,366)) - set(readings)}'
pathlib.Path('src').mkdir(exist_ok=True)
pathlib.Path('src/plan.json').write_text(json.dumps([
    {'day': day, 'reading': readings[day]} for day in sorted(readings)
], indent=2) + '\n', encoding='utf-8')
print('Imported all 365 readings.')
