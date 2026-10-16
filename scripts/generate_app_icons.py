#!/usr/bin/env python3
"""Generates the SLNews launcher icons.

The mark is drawn from primitives (no binary assets in the repo): a Samsung-blue
rounded square with a white "SL" monogram and a news-card glyph, matching the
`primary` design token (`#0381FE`).

    python scripts/generate_app_icons.py

Writes the five Android mipmap densities plus a 1024x1024 store icon under
`assets/branding/`. Existing icons are overwritten.
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

PRIMARY = (3, 129, 254, 255)
WHITE = (255, 255, 255, 255)
PAGE = (241, 241, 241, 0)  # transparent background

ROOT = Path(__file__).resolve().parent.parent
MIPMAPS = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def _font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    """Best-effort font lookup across common Windows/macOS/Linux installs."""
    candidates = [
        Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts" / ("arialbd.ttf" if bold else "arial.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf"),
        Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
        ROOT / "assets" / "fonts" / "Inter-Variable.ttf",
    ]
    for candidate in candidates:
        try:
            if candidate.exists():
                return ImageFont.truetype(str(candidate), size)
        except OSError:
            continue
    return ImageFont.load_default()


def render(size: int, with_padding: bool = True) -> Image.Image:
    """Draws the icon at ``size`` px with 4x supersampling for smooth edges."""
    scale = 4
    canvas = size * scale
    image = Image.new("RGBA", (canvas, canvas), PAGE)
    draw = ImageDraw.Draw(image)

    inset = int(canvas * 0.06) if with_padding else 0
    radius = int(canvas * 0.24)
    draw.rounded_rectangle(
        [inset, inset, canvas - inset, canvas - inset],
        radius=radius,
        fill=PRIMARY,
    )

    # News card glyph: a white rounded sheet with a blue headline band.
    card_w = int(canvas * 0.34)
    card_h = int(canvas * 0.42)
    card_x = int(canvas * 0.54)
    card_y = int(canvas * 0.29)
    draw.rounded_rectangle(
        [card_x, card_y, card_x + card_w, card_y + card_h],
        radius=int(canvas * 0.06),
        fill=WHITE,
    )
    band_h = int(card_h * 0.26)
    draw.rounded_rectangle(
        [card_x, card_y, card_x + card_w, card_y + band_h],
        radius=int(canvas * 0.06),
        fill=(215, 233, 252, 255),
    )
    line_w = int(card_w * 0.62)
    for index, ratio in enumerate((0.48, 0.66, 0.84)):
        y = card_y + int(card_h * ratio)
        width = line_w if index < 2 else int(line_w * 0.6)
        draw.rounded_rectangle(
            [card_x + int(card_w * 0.14), y, card_x + int(card_w * 0.14) + width, y + max(2, int(canvas * 0.022))],
            radius=int(canvas * 0.011),
            fill=(150, 172, 198, 255),
        )

    # "SL" monogram on the left half.
    font = _font(int(canvas * 0.24))
    text = "SL"
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    draw.text(
        (int(canvas * 0.13) - left, int(canvas * 0.5) - (bottom - top) // 2 - top),
        text,
        font=font,
        fill=WHITE,
    )

    return image.resize((size, size), Image.LANCZOS)


def main() -> None:
    for density, size in MIPMAPS.items():
        target = ROOT / "android" / "app" / "src" / "main" / "res" / f"mipmap-{density}" / "ic_launcher.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        render(size).save(target, "PNG")
        print(f"wrote {target.relative_to(ROOT)} ({size}x{size})")

    store_dir = ROOT / "assets" / "branding"
    store_dir.mkdir(parents=True, exist_ok=True)
    store_icon = store_dir / "slnews_icon_1024.png"
    render(1024, with_padding=False).save(store_icon, "PNG")
    print(f"wrote {store_icon.relative_to(ROOT)} (1024x1024)")


if __name__ == "__main__":
    main()
