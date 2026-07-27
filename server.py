from flask import Flask, jsonify, request
import time
import json
import os

app = Flask(__name__)

CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')

DEFAULT_CONFIG = {
    'pereval':  {'green': 132, 'yellow': 3},
    'abaza':    {'green': 42,  'yellow': 3},
    'zarechka': {'green': 42,  'yellow': 3},
    'pause':    60,
    'order':    ['pereval', 'zarechka', 'abaza'],
}

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE) as f:
                cfg = json.load(f)
                if 'pause' not in cfg:
                    cfg['pause'] = 60
                return cfg
        except Exception:
            pass
    return DEFAULT_CONFIG.copy()

def save_config(cfg):
    with open(CONFIG_FILE, 'w') as f:
        json.dump(cfg, f)

config = load_config()
cycle_offset = float(config.get('cycle_offset', 0.0))

def build_phases():
    pause = config.get('pause', 0)
    order = config.get('order', ['pereval', 'zarechka', 'abaza'])
    phases = []
    for road in order:
        phases.append((road,   'green',  config[road]['green']))
        phases.append((road,   'yellow', config[road]['yellow']))
        if pause > 0:
            phases.append(('_pause', 'red', pause))  # все красные
    return phases

def get_states():
    global cycle_offset
    phases = build_phases()
    total = sum(d for _, _, d in phases)
    t = (time.time() - cycle_offset) % total

    # Найти текущую фазу
    elapsed = 0
    active_road, active_state, active_remaining = '_pause', 'red', 0
    for road, state, duration in phases:
        if t < elapsed + duration:
            active_road = road
            active_state = state
            active_remaining = int(elapsed + duration - t)
            break
        elapsed += duration

    # Позиции начала зелёных фаз
    phase_starts = {}
    pos = 0
    for road, state, duration in phases:
        if state == 'green':
            phase_starts[road] = pos
        pos += duration

    result = {}
    for road in ['pereval', 'zarechka', 'abaza']:
        if road == active_road:
            result[road] = {'state': active_state, 'remaining': active_remaining, 'to_green': 0}
        else:
            green_start = phase_starts.get(road, 0)
            to_green = green_start - t
            if to_green < 0:
                to_green += total
            result[road] = {'state': 'red', 'remaining': 0, 'to_green': int(to_green)}

    return result

@app.route('/lights')
def lights():
    return jsonify(get_states())

@app.route('/reset', methods=['POST'])
def reset_cycle():
    global cycle_offset
    data = request.get_json(force=True)
    road = data.get('road', 'pereval')
    phases = build_phases()
    total = sum(d for _, _, d in phases)
    # Найти позицию начала зелёного для нужной дороги
    pos = 0
    for r, state, duration in phases:
        if r == road and state == 'green':
            break
        pos += duration
    # Сдвинуть цикл так чтобы эта позиция совпала с текущим временем
    cycle_offset = time.time() - pos
    config['cycle_offset'] = cycle_offset
    save_config(config)
    return jsonify({'status': 'ok', 'road': road})

@app.route('/config', methods=['GET'])
def get_config():
    return jsonify(config)

@app.route('/config', methods=['POST'])
def set_config():
    data = request.get_json(force=True)
    for road in ['pereval', 'abaza', 'zarechka']:
        if road in data:
            if 'green' in data[road]:
                config[road]['green'] = max(5, min(300, int(data[road]['green'])))
    if 'pause' in data:
        config['pause'] = max(0, min(300, int(data['pause'])))
    if 'order' in data:
        order = data['order']
        if isinstance(order, list) and set(order) == {'pereval', 'abaza', 'zarechka'}:
            config['order'] = order
    save_config(config)
    return jsonify({'status': 'ok', 'config': config})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
