#!/usr/bin/env python3
"""Fetch the latest Tailwind CSS default colors and regenerate tailwind.lua.

Tailwind v4 defines colors in oklch(). This script fetches the source,
parses the oklch values, converts them to sRGB hex, and writes the Lua table.
"""

import math
import re
import urllib.request

COLORS_URL = "https://raw.githubusercontent.com/tailwindlabs/tailwindcss/refs/heads/main/packages/tailwindcss/src/compat/colors.ts"

OUTPUT_PATH = "lua/oklch-color-picker/tailwind.lua"

# Not color scales
SKIP_KEYS = {"inherit", "current", "transparent", "black", "white"}


def fetch(url: str) -> str:
    print(f"Fetching {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "tailwind-color-gen"})
    with urllib.request.urlopen(req) as resp:
        return resp.read().decode()


def oklch_to_oklab(L: float, C: float, h_deg: float) -> tuple[float, float, float]:
    h = math.radians(h_deg)
    return L, C * math.cos(h), C * math.sin(h)


def oklab_to_linear_srgb(L: float, a: float, b: float) -> tuple[float, float, float]:
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b

    l = l_ * l_ * l_
    m = m_ * m_ * m_
    s = s_ * s_ * s_

    r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return r, g, b


def linear_to_srgb(c: float) -> float:
    if c <= 0.0031308:
        return 12.92 * c
    return 1.055 * math.pow(c, 1.0 / 2.4) - 0.055


def oklch_to_hex(L_pct: float, C: float, h: float) -> str:
    """Convert oklch(L% C H) to a #RRGGBB hex string."""
    L = L_pct / 100.0
    lab = oklch_to_oklab(L, C, h)
    r_lin, g_lin, b_lin = oklab_to_linear_srgb(*lab)

    r = max(0.0, min(1.0, linear_to_srgb(r_lin)))
    g = max(0.0, min(1.0, linear_to_srgb(g_lin)))
    b = max(0.0, min(1.0, linear_to_srgb(b_lin)))

    return "#{:02X}{:02X}{:02X}".format(
        int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5)
    )


OKLCH_RE = re.compile(r"oklch\(\s*([\d.]+)%\s+([\d.]+)\s+([\d.]+)\s*\)")


def parse_colors(source: str) -> dict[str, dict[int, str]]:
    """Parse TS source into {name: {shade: hex_string}}."""
    colors: dict[str, dict[int, str]] = {}

    block_re = re.compile(r"""['"]?(\w[\w-]*)['"]?\s*:\s*\{([^}]+)\}""", re.DOTALL)
    entry_re = re.compile(r"""['"]?(\d+)['"]?\s*:\s*['"]([^'"]+)['"]""")

    for m in block_re.finditer(source):
        name = m.group(1)
        if name in SKIP_KEYS:
            continue
        shades: dict[int, str] = {}
        for e in entry_re.finditer(m.group(2)):
            shade = int(e.group(1))
            value = e.group(2).strip()

            # oklch value
            oklch_m = OKLCH_RE.match(value)
            if oklch_m:
                L = float(oklch_m.group(1))
                C = float(oklch_m.group(2))
                H = float(oklch_m.group(3))
                shades[shade] = oklch_to_hex(L, C, H)
            # hex value fallback
            elif value.startswith("#") and len(value) == 7:
                shades[shade] = value.upper()

        if shades:
            colors[name] = shades

    return colors


def generate_lua(colors: dict[str, dict[int, str]]) -> str:
    lines = [
        "local M = {}",
        "",
        "local colors = {",
    ]

    for name, shades in colors.items():
        for shade in sorted(shades):
            hex_val = shades[shade].lstrip("#").upper()
            lines.append(f'  ["{name}-{shade}"] = 0x{hex_val},')

    lines += [
        "}",
        "",
        "--- Returns color of tailwind string, e.g. slate-700",
        "---@param match string",
        "---@return integer",
        "function M.custom_parse(match)",
        "  return colors[match]",
        "end",
        "",
        "return M",
        "",
    ]
    return "\n".join(lines)


def main():
    source = fetch(COLORS_URL)
    colors = parse_colors(source)
    if not colors:
        raise SystemExit("ERROR: No colors parsed. The source format may have changed.")

    print(f"Parsed {len(colors)} color scales: {', '.join(colors)}")

    lua = generate_lua(colors)
    with open(OUTPUT_PATH, "w", newline="\n") as f:
        f.write(lua)

    print(f"Wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
