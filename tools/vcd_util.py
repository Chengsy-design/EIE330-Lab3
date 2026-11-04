"""Minimal VCD reader used for the Lab 3 report figures (stdlib only)."""
import re


class VCD:
    def __init__(self, path):
        self.path = path
        self.vars = {}          # id -> (full_name, width)
        self._scope = []
        self._data = {}         # id -> list of (time, value)
        self._last = {}
        self.end_time = 0
        self._parse()

    def _parse(self):
        time = 0
        with open(self.path, 'r', errors='replace') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                if line.startswith('$var'):
                    tok = line.split()
                    # $var wire 16 # rgb [15:0] $end
                    width = int(tok[2])
                    vid = tok[3]
                    name = tok[4]
                    full = '.'.join(self._scope + [name]) if self._scope else name
                    self.vars[vid] = (full, width)
                    self._data.setdefault(vid, [])
                    continue
                if line.startswith('$scope'):
                    tok = line.split()
                    self._scope.append(tok[2])
                    continue
                if line.startswith('$upscope'):
                    if self._scope:
                        self._scope.pop()
                    continue
                if line.startswith('$end') or line.startswith('$comment'):
                    continue
                if line.startswith('#'):
                    time = int(line[1:])
                    self.end_time = max(self.end_time, time)
                    continue
                if line.startswith('$'):
                    continue
                if line[0] in '01xzXZ':
                    val = None if line[0] in 'xzXZ' else int(line[0])
                    vid = line[1:]
                    self._add(vid, time, val)
                elif line[0] in 'bB':
                    body = line[1:].split()
                    bits = body[0]
                    vid = body[1]
                    if any(c in bits for c in 'xzXZ'):
                        val = None
                    else:
                        val = int(bits, 2)
                    self._add(vid, time, val)
                elif line[0] in 'rR':
                    body = line[1:].split()
                    val = float(body[0])
                    vid = body[1]
                    self._add(vid, time, val)

    def _add(self, vid, time, val):
        if vid not in self._data:
            return
        if vid in self._last and self._last[vid] == val:
            return
        self._last[vid] = val
        self._data[vid].append((time, val))

    def names(self):
        return sorted({v[0] for v in self.vars.values()})

    def find(self, suffix):
        """Return the first full name ending with .suffix (or equal)."""
        for vid, (name, width) in self.vars.items():
            if name == suffix or name.endswith('.' + suffix):
                return name
        return None

    def series(self, suffix):
        name = self.find(suffix)
        if name is None:
            raise KeyError(suffix)
        for vid, (n, w) in self.vars.items():
            if n == name:
                return self._data[vid]
        raise KeyError(suffix)

    def value_at(self, series, t, default=0):
        val = default
        for tt, vv in series:
            if tt > t:
                break
            val = vv
        return val
