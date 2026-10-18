"""Generate SLNews brand and Play Store assets.

One source of truth for the launcher icon, adaptive icon, splash wordmark and the
Play listing images, so a brand tweak is a one-line change plus a rerun instead of
hand-editing a dozen PNGs.

    python tools/generate_store_assets.py

Listing visual language follows the Samsung News reference the owner supplied:
alternating black / light full-bleed backgrounds, one large headline per screen, a
device mockup that runs off the bottom edge, a brand lockup on the landscape art,
and a three-panel promo sheet.

Outputs
-------
Android launcher
    android/app/src/main/res/mipmap-*/ic_launcher.png            legacy square
    android/app/src/main/res/mipmap-*/ic_launcher_foreground.png adaptive foreground
    android/app/src/main/res/mipmap-*/ic_launcher_monochrome.png  themed-icon layer
    android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml    adaptive descriptor
    android/app/src/main/res/values/ic_launcher_background.xml   background colour
Splash
    android/app/src/main/res/drawable-*/splash_logo.png
    android/app/src/main/res/drawable{,-v21}/launch_background.xml
Play listing
    store/play/icon-512.png
    store/play/feature-graphic-1024x500.png
    store/play/promo-panels-1350x800.png
    store/play/screenshots/phone-*.png

Screenshots are composed from device renders in `store/play/captures/` when
present, otherwise from the app-level golden renders (1080x2202). Drop real phone
captures there with the same names and rerun for final listing art.
"""

from __future__ import annotations

import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent

BLACK = (17, 17, 17)
WHITE = (255, 255, 255)
PANEL_LIGHT = (242, 242, 242)
GREY = (107, 107, 107)
BLUE = (3, 129, 254)
BEZEL = (250, 250, 250)
FRAME_EDGE = (208, 208, 208)

FONT_PATH = ROOT / "assets" / "fonts" / "Inter-Variable.ttf"

RES = ROOT / "android" / "app" / "src" / "main" / "res"
STORE = ROOT / "store" / "play"
GOLDENS = ROOT / "test" / "golden" / "goldens"
CAPTURES = STORE / "captures"

DENSITY_SCALE = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}


def font(size: int, weight: int = 700) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(str(FONT_PATH), size)
    try:
        # Inter is variable: optical size 14-32, weight 100-900.
        face.set_variation_by_axes([max(14, min(32, int(size / 4))), weight])
    except Exception:  # pragma: no cover - older FreeType builds
        pass
    return face


def save(image: Image.Image, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"  {path.relative_to(ROOT)}")


# --------------------------------------------------------------------------
# Brand marks
# --------------------------------------------------------------------------
def rounded(size: int, radius_ratio: float = 0.22) -> Image.Image:
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(tile).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=int(size * radius_ratio), fill=BLACK + (255,)
    )
    return tile


def sl_mark(size: int, colour: tuple[int, int, int] = WHITE) -> Image.Image:
    """The "SL." monogram: letters plus the brand-blue dot."""
    mark = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(mark)
    face = font(int(size * 0.58), weight=800)
    text = "SL"
    box = draw.textbbox((0, 0), text, font=face)
    text_w, text_h = box[2] - box[0], box[3] - box[1]
    dot_r = int(size * 0.075)
    gap = int(size * 0.035)
    total_w = text_w + gap + dot_r * 2
    left = (size - total_w) // 2
    top = (size - text_h) // 2 - box[1]
    draw.text((left - box[0], top), text, font=face, fill=colour + (255,))
    dot_cy = (size - text_h) // 2 + text_h - dot_r
    draw.ellipse(
        (
            left + text_w + gap,
            dot_cy - dot_r,
            left + text_w + gap + dot_r * 2,
            dot_cy + dot_r,
        ),
        fill=BLUE + (255,),
    )
    return mark


def wordmark(width: int, colour: tuple[int, int, int] = BLACK) -> Image.Image:
    """Wordmark with a short accent rule underneath, used for the splash."""
    height = int(width * 0.30)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    face = font(int(width * 0.26), weight=800)
    text = "SLNews"
    box = draw.textbbox((0, 0), text, font=face)
    text_w, text_h = box[2] - box[0], box[3] - box[1]
    draw.text(
        ((width - text_w) // 2 - box[0], int(height * 0.16) - box[1]),
        text,
        font=face,
        fill=colour + (255,),
    )
    rule_w = int(text_w * 0.42)
    rule_y = int(height * 0.16) + text_h + int(height * 0.10)
    draw.rounded_rectangle(
        ((width - rule_w) // 2, rule_y, (width + rule_w) // 2, rule_y + max(3, height // 22)),
        radius=max(2, height // 44),
        fill=BLUE + (255,),
    )
    return canvas


def lockup(height: int, on_dark: bool = False) -> Image.Image:
    """App-icon squircle + wordmark, as on the reference promo images."""
    icon = rounded(height, radius_ratio=0.28)
    icon.alpha_composite(sl_mark(int(height * 0.94)))
    label = "SLNews"
    face = font(int(height * 0.72), weight=800)
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    box = probe.textbbox((0, 0), label, font=face)
    text_w = box[2] - box[0]
    gap = int(height * 0.32)
    canvas = Image.new("RGBA", (height + gap + text_w + 8, height), (0, 0, 0, 0))
    canvas.alpha_composite(icon, (0, 0))
    ImageDraw.Draw(canvas).text(
        (height + gap - box[0], (height - (box[3] - box[1])) // 2 - box[1]),
        label,
        font=face,
        fill=(WHITE if on_dark else BLACK) + (255,),
    )
    return canvas


# --------------------------------------------------------------------------
# Device mockup
# --------------------------------------------------------------------------
def status_bar(screen: Image.Image, width: int, band: int, ink: tuple[int, int, int]) -> None:
    """Status band drawn above the app content, the way the reference shows one.

    `ink` is dark on a light app bar, light on a dark one, so the glyphs read.
    """
    draw = ImageDraw.Draw(screen)
    colour = ink + (235,)
    face = font(int(band * 0.40), weight=600)
    draw.text((int(width * 0.07), int(band * 0.24)), "12:45", font=face, fill=colour)
    base_x = int(width * 0.70)
    bar_w = max(2, int(width * 0.008))
    for index in range(4):
        bar_h = int(band * (0.22 + index * 0.08))
        draw.rectangle(
            (
                base_x + index * (bar_w + 3),
                int(band * 0.72) - bar_h,
                base_x + index * (bar_w + 3) + bar_w,
                int(band * 0.72),
            ),
            fill=colour,
        )
    wx = int(width * 0.82)
    draw.polygon(
        [
            (wx, int(band * 0.44)),
            (wx + int(width * 0.05), int(band * 0.44)),
            (wx + int(width * 0.025), int(band * 0.68)),
        ],
        fill=colour,
    )
    bx = int(width * 0.90)
    draw.rounded_rectangle(
        (bx, int(band * 0.38), bx + int(width * 0.052), int(band * 0.68)),
        radius=3,
        outline=colour,
        width=2,
    )
    draw.rectangle(
        (bx + 3, int(band * 0.44), bx + int(width * 0.038), int(band * 0.62)),
        fill=(90, 190, 90, 235),
    )


def phone_mockup(screen_source: Image.Image, width: int) -> Image.Image:
    """A framed phone with the capture inside, cropped to a device ratio."""
    height = int(width * 2.04)
    bezel = max(7, int(width * 0.021))
    radius = int(width * 0.115)

    frame = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)
    draw.rounded_rectangle(
        (0, 0, width - 1, height - 1), radius=radius, fill=BEZEL + (255,)
    )
    draw.rounded_rectangle(
        (0, 0, width - 1, height - 1),
        radius=radius,
        outline=FRAME_EDGE + (255,),
        width=max(2, int(width * 0.008)),
    )

    inner_w = width - bezel * 2
    inner_h = height - bezel * 2
    band = max(10, int(inner_w * 0.062))

    # Our Flutter captures start at the app bar (no system status bar), so the
    # band is drawn above the content rather than over it.
    background = screen_source.getpixel((2, 2))
    luminance = 0.299 * background[0] + 0.587 * background[1] + 0.114 * background[2]
    ink = (17, 17, 17) if luminance > 140 else (255, 255, 255)

    inner = Image.new("RGB", (inner_w, inner_h), background)
    content_h = inner_h - band
    scale = max(inner_w / screen_source.width, content_h / screen_source.height)
    resized = screen_source.resize(
        (int(screen_source.width * scale) + 1, int(screen_source.height * scale) + 1),
        Image.LANCZOS,
    )
    left = (resized.width - inner_w) // 2
    cropped = resized.crop((left, 0, left + inner_w, content_h))
    inner.paste(cropped, (0, band))
    status_bar(inner, inner_w, band, ink)

    mask = Image.new("L", (inner_w, inner_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, inner_w - 1, inner_h - 1), radius=int(radius * 0.82), fill=255
    )
    frame.paste(inner.convert("RGBA"), (bezel, bezel), mask)
    return frame


def paste_with_shadow(canvas: Image.Image, phone: Image.Image, x: int, y: int) -> None:
    shadow = Image.new("RGBA", (phone.width + 120, phone.height + 120), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (60, 60, shadow.width - 61, shadow.height - 61),
        radius=int(phone.width * 0.12),
        fill=(0, 0, 0, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.alpha_composite(shadow, (x - 60, y - 40))
    canvas.alpha_composite(phone, (x, y))


def headline(
    draw: ImageDraw.ImageDraw,
    lines: list[str],
    top: int,
    size: int,
    colour: tuple[int, int, int],
    width: int,
) -> int:
    """Centred multi-line headline; returns the y below the last line."""
    face = font(size, weight=800)
    y = top
    for line in lines:
        box = draw.textbbox((0, 0), line, font=face)
        draw.text(
            ((width - (box[2] - box[0])) // 2 - box[0], y - box[1]),
            line,
            font=face,
            fill=colour,
        )
        y += int((box[3] - box[1]) * 1.32)
    return y


# --------------------------------------------------------------------------
# Android assets
# --------------------------------------------------------------------------
def build_launcher_icons() -> None:
    print("Launcher icons")
    master = 512
    tile = rounded(master)
    tile.alpha_composite(sl_mark(master))
    for density, scale in DENSITY_SCALE.items():
        target = int(48 * scale)
        save(
            tile.resize((target, target), Image.LANCZOS),
            RES / f"mipmap-{density}" / "ic_launcher.png",
        )

    for density, scale in DENSITY_SCALE.items():
        canvas_px = int(108 * scale)
        safe_px = int(66 * scale)
        layer = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
        layer.alpha_composite(
            sl_mark(safe_px), ((canvas_px - safe_px) // 2, (canvas_px - safe_px) // 2)
        )
        save(layer, RES / f"mipmap-{density}" / "ic_launcher_foreground.png")

        mono = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
        mono_mark = sl_mark(safe_px, colour=WHITE)
        ImageDraw.Draw(mono_mark).ellipse(
            (
                int(safe_px * 0.70),
                int(safe_px * 0.72),
                int(safe_px * 0.86),
                int(safe_px * 0.88),
            ),
            fill=WHITE + (255,),
        )
        mono.alpha_composite(
            mono_mark, ((canvas_px - safe_px) // 2, (canvas_px - safe_px) // 2)
        )
        save(mono, RES / f"mipmap-{density}" / "ic_launcher_monochrome.png")

    descriptor = """<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tools/generate_store_assets.py - rerun instead of editing. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""
    path = RES / "mipmap-anydpi-v26" / "ic_launcher.xml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(descriptor, encoding="utf-8")
    print(f"  {path.relative_to(ROOT)}")

    colours = """<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tools/generate_store_assets.py - rerun instead of editing. -->
<resources>
    <color name="ic_launcher_background">#111111</color>
</resources>
"""
    path = RES / "values" / "ic_launcher_background.xml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(colours, encoding="utf-8")
    print(f"  {path.relative_to(ROOT)}")


def build_splash() -> None:
    print("Splash")
    for density, scale in DENSITY_SCALE.items():
        save(wordmark(int(220 * scale)), RES / f"drawable-{density}" / "splash_logo.png")

    background = """<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tools/generate_store_assets.py - rerun instead of editing. -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="#F1F1F1" />
        </shape>
    </item>
    <item android:gravity="center">
        <bitmap android:gravity="center" android:src="@drawable/splash_logo" />
    </item>
</layer-list>
"""
    for folder in ("drawable", "drawable-v21"):
        path = RES / folder / "launch_background.xml"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(background, encoding="utf-8")
        print(f"  {path.relative_to(ROOT)}")


# --------------------------------------------------------------------------
# Play listing
# --------------------------------------------------------------------------
SCREENSHOTS: list[tuple[str, list[str], bool]] = [
    ("for_you", ["Your day in", "one feed"], True),
    ("news", ["Browse by", "section"], False),
    ("sports", ["Scores and", "fixtures"], True),
    ("article", ["Read without", "the clutter"], False),
    ("section", ["Top stories,", "all of them"], True),
    ("search", ["Search every", "story"], False),
    ("following", ["Follow what", "matters"], True),
]

PROMO_PANELS: list[tuple[list[str], str, bool]] = [
    (["Stay up", "to date"], "for_you", True),
    (["Get news from", "every angle"], "sports", False),
    (["Personalize", "your feed"], "following", True),
]


def screen_source(name: str) -> Image.Image | None:
    capture = CAPTURES / f"{name}.png"
    source = capture if capture.exists() else GOLDENS / f"{name}.png"
    if not source.exists():
        print(f"  skipping {name}: no source")
        return None
    return Image.open(source).convert("RGB")


def build_play_images() -> None:
    print("Play listing images")
    icon = Image.new("RGB", (512, 512), BLACK)
    icon.paste(sl_mark(512), (0, 0), sl_mark(512))
    save(icon, STORE / "icon-512.png")

    # Feature graphic: light field, brand lockup, left-aligned headline, and an
    # abstract feed on the right (no device frames, per Play's guidance).
    w, h = 1024, 500
    graphic = Image.new("RGB", (w, h), PANEL_LIGHT)
    draw = ImageDraw.Draw(graphic)
    brand = lockup(60)
    graphic.paste(brand, (56, 44), brand)

    face = font(56, weight=800)
    draw.text((58, 168), "Sierra Leone,", font=face, fill=BLACK)
    draw.text((58, 236), "one feed.", font=face, fill=BLACK)
    draw.rounded_rectangle((58, 320, 190, 330), radius=5, fill=BLUE)
    draw.text(
        (58, 356),
        "News  ·  Sports  ·  Markets  ·  Video",
        font=font(22, weight=600),
        fill=GREY,
    )

    bars = [
        (0.60, 0.16, 0.94, 0.205),
        (0.60, 0.27, 0.87, 0.315),
        (0.60, 0.38, 0.74, 0.425),
        (0.66, 0.60, 0.97, 0.645),
        (0.66, 0.71, 0.90, 0.755),
        (0.66, 0.82, 0.78, 0.865),
    ]
    shades = [(32, 32, 32), (122, 122, 122), (168, 168, 168)]
    for index, (x0, y0, x1, y1) in enumerate(bars):
        shade = shades[index % 3]
        draw.rounded_rectangle(
            (int(w * x0), int(h * y0), int(w * x1), int(h * y1)),
            radius=9,
            fill=shade,
        )
    draw.rounded_rectangle(
        (int(w * 0.60), int(h * 0.49), int(w * 0.76), int(h * 0.52)),
        radius=6,
        fill=BLUE,
    )
    save(graphic, STORE / "feature-graphic-1024x500.png")

    # Three-panel promo, mirroring the reference's landscape sheet.
    pw, ph = 1350, 800
    promo = Image.new("RGB", (pw, ph), BLACK)
    panel_w = pw // 3
    for index, (lines, capture_name, dark) in enumerate(PROMO_PANELS):
        panel = Image.new("RGBA", (panel_w, ph), (BLACK if dark else PANEL_LIGHT) + (255,))
        pdraw = ImageDraw.Draw(panel)
        headline(pdraw, lines, 96, 46, WHITE if dark else BLACK, panel_w)
        source = screen_source(capture_name)
        if source is not None:
            phone = phone_mockup(source, int(panel_w * 0.66))
            paste_with_shadow(panel, phone, (panel_w - phone.width) // 2, 300)
        promo.paste(panel.convert("RGB"), (index * panel_w, 0))
    save(promo, STORE / "promo-panels-1350x800.png")


def build_screenshots() -> None:
    print("Phone screenshots")
    phone_w, phone_h = 1080, 1920
    for index, (name, lines, dark) in enumerate(SCREENSHOTS, start=1):
        source = screen_source(name)
        if source is None:
            continue

        background = BLACK if dark else PANEL_LIGHT
        frame = Image.new("RGBA", (phone_w, phone_h), background + (255,))
        draw = ImageDraw.Draw(frame)
        headline(draw, lines, 132, 96, WHITE if dark else BLACK, phone_w)

        phone = phone_mockup(source, int(phone_w * 0.73))
        x = (phone_w - phone.width) // 2
        # Runs off the bottom edge, as in the reference.
        paste_with_shadow(frame, phone, x, int(phone_h * 0.31))

        save(
            frame.convert("RGB"),
            STORE / "screenshots" / f"phone-{index:02d}-{name}.png",
        )


def main() -> int:
    if not FONT_PATH.exists():
        print(f"missing font: {FONT_PATH}", file=sys.stderr)
        return 1
    build_launcher_icons()
    build_splash()
    build_play_images()
    build_screenshots()
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
