# /// script
# requires-python = ">=3.10"
# dependencies = ["coloraide==8.13.1"]
# ///
"""Regenerate tailwind.lua from Tailwind's default colors on main.

Run from the repository root: uv run scripts/generate_tailwind_colors.py
"""

import re
import urllib.request

from coloraide import Color

COLORS_URL = "https://raw.githubusercontent.com/tailwindlabs/tailwindcss/refs/heads/main/packages/tailwindcss/src/compat/colors.ts"

OUTPUT_PATH = "lua/oklch-color-picker/tailwind.lua"

def main():
    print(f"Fetching {COLORS_URL}")
    req = urllib.request.Request(COLORS_URL, headers={"User-Agent": "tailwind-color-gen"})
    with urllib.request.urlopen(req) as resp:
        source = resp.read().decode()

    block_re = re.compile(r"""['"]?(\w[\w-]*)['"]?\s*:\s*\{([^}]+)\}""", re.DOTALL)
    entry_re = re.compile(r"""['"]?(\d+)['"]?\s*:\s*['"]([^'"]+)['"]""")

    rows = []
    for name, block in block_re.findall(source):
        for shade, value in sorted(entry_re.findall(block), key=lambda entry: int(entry[0])):
            # Clip out-of-gamut channels to preserve the palette's sRGB values.
            hex_value = Color(value).convert("srgb").to_string(
                hex=True, fit="clip", compress=False, upper=True
            )
            rows.append(f'  ["{name}-{shade}"] = 0x{hex_value[1:]},')

    if not rows:
        raise SystemExit("ERROR: No colors parsed. The source format may have changed.")

    entries = "\n".join(rows)
    lua = f"""local M = {{}}

local colors = {{
{entries}
}}

--- Returns color of tailwind string, e.g. slate-700
---@param match string
---@return integer
function M.custom_parse(match)
  return colors[match]
end

return M
"""
    with open(OUTPUT_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(lua)

    print(f"Wrote {len(rows)} colors to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
