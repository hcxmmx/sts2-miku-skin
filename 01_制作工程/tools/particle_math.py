"""Pure sampling helpers reused from SchneiderSkin/tools/particle_core.py."""
import math
import numpy as np

DURATION = 2.2

def curve(keys, t):
    keys = keys.get('m_Curve', []) if isinstance(keys, dict) else keys
    if not keys:
        return 0.0
    if t <= keys[0]['time']:
        return keys[0]['value']
    if t >= keys[-1]['time']:
        return keys[-1]['value']
    for a, b in zip(keys, keys[1:]):
        if a['time'] <= t <= b['time']:
            dt = b['time'] - a['time']
            u = (t - a['time']) / dt
            if not math.isfinite(a['outSlope']) or not math.isfinite(b['inSlope']):
                return a['value']
            return ((2*u**3-3*u*u+1)*a['value'] + (u**3-2*u*u+u)*dt*a['outSlope']
                    + (-2*u**3+3*u*u)*b['value'] + (u**3-u*u)*dt*b['inSlope'])
    return keys[-1]['value']


def mm(d, t=0, r=0.5):
    state = d.get('minMaxState', 0)
    high, low = d.get('scalar', 0), d.get('minScalar', 0)
    if state == 0:
        return high
    if state == 1:
        return curve(d['maxCurve'], t) * high
    if state == 2:
        return (curve(d['minCurve'], t)*(1-r) + curve(d['maxCurve'], t)*r)*high
    return low*(1-r) + high*r


def gradient(d, t):
    colors = [(d['ctime'+str(i)] / 65535, np.array([d['key'+str(i)][k] for k in 'rgb'])) for i in range(d['m_NumColorKeys'])]
    alphas = [(d['atime'+str(i)] / 65535, d['key'+str(i)]['a']) for i in range(d['m_NumAlphaKeys'])]
    def interp(keys):
        if not keys:
            return 1.0
        if t <= keys[0][0]:
            return keys[0][1]
        for a, b in zip(keys, keys[1:]):
            if t <= b[0]:
                u = 0 if d.get('m_Mode') == 1 else (t-a[0]) / max(b[0]-a[0], 1e-8)
                return a[1]*(1-u)+b[1]*u
        return keys[-1][1]
    return np.append(interp(colors), interp(alphas))


def color(d, t, r):
    state = d['minMaxState']
    a = np.array([d['maxColor'][k] for k in 'rgba'])
    b = np.array([d['minColor'][k] for k in 'rgba'])
    if state == 0:
        return a
    if state == 1:
        return gradient(d['maxGradient'], t)
    if state == 2:
        return b*(1-r)+a*r
    if state == 3:
        return gradient(d['minGradient'], t)*(1-r)+gradient(d['maxGradient'], t)*r
    return gradient(d['maxGradient'], r)


def vec(d):
    return np.array([d[k] for k in 'xyz'], dtype=float)


def rotation(x, y, z):
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rx = np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]])
    ry = np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]])
    rz = np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]])
    return ry @ rx @ rz


def transform(chain):
    out = np.eye(4)
    for tr in chain:
        q = tr['m_LocalRotation']
        x, y, z, w = (q[k] for k in 'xyzw')
        rot = np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],
                        [2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],
                        [2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]])
        mat = np.eye(4)
        mat[:3,:3] = rot @ np.diag(vec(tr['m_LocalScale']))
        mat[:3,3] = vec(tr['m_LocalPosition'])
        out = out @ mat
    return out


def shape_sample(d, rng):
    if not d.get('enabled'):
        return np.zeros(3), np.array([0.,0.,1.])
    typ = d['type']
    phi = rng.uniform(0, math.tau)
    r = mm({'scalar': d.get('radius', {}).get('value', 1)})
    if typ in [0,1,2,3]:
        direction = rng.normal(size=3)
        direction /= np.linalg.norm(direction)
        if typ in [2,3]: direction[2] = abs(direction[2])
        p = direction*r*(rng.random()**(1/3) if typ in [0,2] else 1)
    elif typ in [4,8,9]:
        rad = r*math.sqrt(rng.random())
        p = np.array([math.cos(phi)*rad,math.sin(phi)*rad,0.])
        theta = math.radians(d.get('angle', 0))*math.sqrt(rng.random())
        direction = np.array([math.sin(theta)*math.cos(phi),math.sin(theta)*math.sin(phi),math.cos(theta)])
    elif typ in [10,11]:
        p = np.array([math.cos(phi),math.sin(phi),0])*r*math.sqrt(rng.random())
        direction = np.array([math.cos(phi),math.sin(phi),0])
    else:
        p = rng.uniform(-.5,.5,size=3)
        direction = np.array([0.,0.,1.])
    rot = rotation(*np.radians(vec(d['m_Rotation'])))
    return rot @ (p*vec(d['m_Scale']))+vec(d['m_Position']), rot @ direction


def birth_times(ps, rng, duration=DURATION, distance_at=None):
    emission = ps['EmissionModule']
    if not emission['enabled']:
        return []
    delay = mm(ps['startDelay'], r=rng.random())
    length = ps['lengthInSec']
    times = []
    for burst in emission.get('m_Bursts', []):
        for cycle in range(max(1, burst['cycleCount'])):
            t = burst['time'] + cycle*burst['repeatInterval']
            if rng.random() <= burst['probability']:
                count = max(0, int(round(mm(burst['countCurve'],t/max(length,.001),rng.random()))))
                times.extend([delay+t]*count)
    # Numerical emission integral supports curves and avoids frame-rate dependence.
    acc = 0.
    for n in range(math.ceil(min(length, duration)*120)):
        t = n/120
        acc += max(0,mm(emission['rateOverTime'],t/max(length,.001),.5))/120
        while acc >= 1:
            times.append(delay+t)
            acc -= 1
    if distance_at is not None:
        acc = 0.0
        previous = distance_at(delay)
        for n in range(1, math.ceil(min(length, duration) * 120) + 1):
            t = n / 120
            current = distance_at(delay + t)
            acc += np.linalg.norm(current - previous) * max(0, mm(emission['rateOverDistance'], t / max(length, .001)))
            while acc >= 1:
                times.append(delay + t)
                acc -= 1
            previous = current
    if ps['looping']:
        first = list(times)
        for cycle in range(1,math.ceil(duration/max(length,.01))):
            times.extend([t+cycle*length for t in first])
    return sorted(t for t in times if t <= duration)


def integrate(d, q, r):
    return sum(mm(d,q*(n+.5)/8,r) for n in range(8))/8
