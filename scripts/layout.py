#!/usr/bin/env python3
import re
import sys

CELL = re.compile(r"(\d+)x(\d+),(\d+),(\d+)")


def parse(s):
    s = s.split(",", 1)[1] if re.match(r"^[0-9a-f]{4},", s) else s
    i = 0

    def cell():
        nonlocal i
        m = CELL.match(s, i)
        if not m:
            raise ValueError(f"bad layout at {i}: {s}")
        w, h, x, y = map(int, m.groups())
        i = m.end()
        c = {"w": w, "h": h, "x": x, "y": y}
        if i < len(s) and s[i] in "{[":
            c["kind"] = "lr" if s[i] == "{" else "tb"
            close = "}" if s[i] == "{" else "]"
            i += 1
            c["kids"] = [cell()]
            while s[i] == ",":
                i += 1
                c["kids"].append(cell())
            if s[i] != close:
                raise ValueError(f"expected {close} at {i}: {s}")
            i += 1
        else:
            m = re.compile(r",(\d+)").match(s, i)
            if not m:
                raise ValueError(f"missing pane id at {i}: {s}")
            c["id"] = int(m.group(1))
            i = m.end()
        return c

    root = cell()
    if i != len(s):
        raise ValueError(f"trailing data at {i}: {s}")
    return root


def dump(c):
    head = f"{c['w']}x{c['h']},{c['x']},{c['y']}"
    if "kids" in c:
        o, e = ("{", "}") if c["kind"] == "lr" else ("[", "]")
        return head + o + ",".join(dump(k) for k in c["kids"]) + e
    return f"{head},{c['id']}"


def checksum(s):
    csum = 0
    for ch in s:
        csum = (csum >> 1) + ((csum & 1) << 15)
        csum = (csum + ord(ch)) & 0xFFFF
    return f"{csum:04x},{s}"


def split(total, weights):
    s = sum(weights) or len(weights)
    weights = weights if sum(weights) else [1] * len(weights)
    out, acc, cum = [], 0, 0
    for wt in weights:
        cum += wt
        v = round(cum * total / s)
        out.append(v - acc)
        acc = v
    if min(out) < 1:
        raise ValueError(f"cannot fit {weights} into {total}")
    return out


def place(c, x, y, w, h):
    if w < 1 or h < 1:
        raise ValueError(f"cell too small: {w}x{h}")
    kw, kh = [k["w"] for k in c.get("kids", [])], [k["h"] for k in c.get("kids", [])]
    c.update(x=x, y=y, w=w, h=h)
    if c.get("kind") == "lr":
        pos = x
        for k, sz in zip(c["kids"], split(w - len(kw) + 1, kw)):
            place(k, pos, y, sz, h)
            pos += sz + 1
    elif c.get("kind") == "tb":
        pos = y
        for k, sz in zip(c["kids"], split(h - len(kh) + 1, kh)):
            place(k, x, pos, w, sz)
            pos += sz + 1


def ids(c):
    return [c["id"]] if "id" in c else [i for k in c["kids"] for i in ids(k)]


def content(root, sid):
    if root.get("kind") == "lr" and any(k.get("id") == sid for k in root["kids"]):
        kids = [k for k in root["kids"] if k.get("id") != sid]
        if len(kids) == 1:
            return kids[0]
        return {**root, "kids": kids}
    return root


def with_sidebar(layout, W, H, sid, sw):
    body = content(parse(layout), sid)
    place(body, sw + 1, 0, W - sw - 1, H)
    side = {"w": sw, "h": H, "x": 0, "y": 0, "id": sid}
    kids = [side] + (body["kids"] if body.get("kind") == "lr" else [body])
    return checksum(dump({"w": W, "h": H, "x": 0, "y": 0, "kind": "lr", "kids": kids}))


def without_sidebar(layout, W, H, sid):
    body = content(parse(layout), sid)
    place(body, 0, 0, W, H)
    return checksum(dump(body))


def main():
    cmd, layout, W, H, sid = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
    if cmd == "with":
        print(with_sidebar(layout, W, H, sid, int(sys.argv[6])))
    elif cmd == "without":
        print(without_sidebar(layout, W, H, sid))
    else:
        raise SystemExit(f"unknown command {cmd}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"layout.py {sys.argv[1:]}: {e}", file=sys.stderr)
        sys.exit(1)
