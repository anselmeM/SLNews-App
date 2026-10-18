"""Generate SLNews brand and Play Store assets.

One source of truth for the launcher icon, adaptive icon, splash wordmark and the
Play listing images, so a brand tweak is a one-line change plus a rerun instead of
hand-editing a dozen PNGs.

    python tools/generate_store_assets.py

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
    store/play/screenshots/phone-*.png

Screenshots are composed from the app-level golden renders (1080x2202) because
this toolchain has no device or emulator attached. Once real captures exist, drop
them in `store/play/captures/` and rerun: anything found there is used instead of
the golden for the matching screen name.
"""

from __future__ import annotations

import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent

BLACK = (17, 17, 17)          # onSurface / surfaceInverse
WHITE = (255, 255, 255)
CANVAS = (241, 241, 241)      # app canvas
BLUE = (3, 129, 254)          # primary accent
GREY = (107, 107, 107)        # onSurfaceVariant

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
        face.set_variation_by_axes([max(14, min(32, int(size / 6))), weight])
    except Exception:  # pragma: no cover - older FreeType builds
        pass
    return face


def rounded(size: int, radius_ratio: float = 0.22) -> Image.Image:
    """A full-bleed dark tile with rounded corners, at 4x for clean downscaling."""
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(tile)
    radius = int(size * radius_ratio)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=BLACK + (255,))
    return tile


def sl_mark(size: int, colour: tuple[int, int, int] = WHITE) -> Image.Image:
    """The "SL." monogram: white letters, blue dot. Transparent background."""
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
    x = (width - text_w) // 2 - box[0]
    y = int(height * 0.16) - box[1]
    draw.text((x, y), text, font=face, fill=colour + (255,))
    rule_w = int(text_w * 0.42)
    rule_y = int(height * 0.16) + text_h + int(height * 0.10)
    draw.rounded_rectangle(
        ((width - rule_w) // 2, rule_y, (width + rule_w) // 2, rule_y + max(3, height // 22)),
        radius=max(2, height // 44),
        fill=BLUE + (255,),
    )
    return canvas


def save(image: Image.Image, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"  {path.relative_to(ROOT)}")


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

    # Adaptive foreground: 108dp canvas, mark inside the 66dp safe circle.
    for density, scale in DENSITY_SCALE.items():
        canvas_px = int(108 * scale)
        safe_px = int(66 * scale)
        layer = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
        mark = sl_mark(safe_px)
        layer.alpha_composite(mark, ((canvas_px - safe_px) // 2, (canvas_px - safe_px) // 2))
        save(layer, RES / f"mipmap-{density}" / "ic_launcher_foreground.png")

        mono = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
        mono_mark = sl_mark(safe_px, colour=WHITE)
        # Themed icons tint the whole layer, so the dot must be white too.
        mono_mark_draw = ImageDraw.Draw(mono_mark)
        mono_mark_draw.ellipse(
            (
                int(safe_px * 0.70),
                int(safe_px * 0.72),
                int(safe_px * 0.86),
                int(safe_px * 0.88),
            ),
            fill=WHITE + (255,),
        )
        mono.alpha_composite(mono_mark, ((canvas_px - safe_px) // 2, (canvas_px - safe_px) // 2))
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
        width = int(220 * scale)
        logo = wordmark(width)
        save(logo, RES / f"drawable-{density}" / "splash_logo.png")

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


def build_play_images() -> None:
    print("Play listing images")
    # Play icon: full-bleed 512x512, no alpha.
    icon = Image.new("RGB", (512, 512), BLACK)
    icon.paste(sl_mark(512), (0, 0), sl_mark(512))
    save(icon, STORE / "icon-512.png")

    # Feature graphic 1024x500.
    w, h = 1024, 500
    graphic = Image.new("RGB", (w, h), BLACK)
    draw = ImageDraw.Draw(graphic)
    graphic = graphic.convert("RGB")
    draw = ImageDraw.Draw(graphic)
    # Right side: an abstract feed of headline bars, so the frame is not a wall
    # of text and still says "news".
    bars = [
        (0.56, 0.30, 0.86, 0.335, (255, 255, 255, 215)),
        (0.56, 0.37, 0.80, 0.405, (255, 255, 255, 150)),
        (0.56, 0.44, 0.70, 0.475, (255, 255, 255, 95)),
        (0.62, 0.60, 0.92, 0.635, (255, 255, 255, 215)),
        (0.62, 0.67, 0.86, 0.705, (255, 255, 255, 150)),
        (0.62, 0.74, 0.76, 0.775, (255, 255, 255, 95)),
    ]
    for x0, y0, x1, y1, fill in bars:
        draw.rounded_rectangle(
            (int(w * x0), int(h * y0), int(w * x1), int(h * y1)),
            radius=10,
            fill=fill,
        )
    draw.rounded_rectangle(
        (int(w * 0.56), int(h * 0.53), int(w * 0.71), int(h * 0.555)),
        radius=8,
        fill=BLUE,
    )
    draw.rounded_rectangle((60, 150, 96, 350), radius=18, fill=BLUE)
    draw.text((130, 168), "SLNews", font=font(96, weight=800), fill=WHITE)
    draw.text(
        (134, 292),
        "Sierra Leone, one feed.",
        font=font(40, weight=500),
        fill=(241, 241, 241),
    )
    draw.text(
        (134, 356),
        "News  ·  Sports  ·  Markets  ·  Video",
        font=font(26, weight=500),
        fill=GREY,
    )
    save(graphic, STORE / "feature-graphic-1024x500.png")


SCREENSHOTS: list[tuple[str, str]] = [
    ("for_you", "Your day in one feed"),
    ("news", "Browse by section"),
    ("sports", "Scores and fixtures"),
    ("article", "Read without the clutter"),
    ("section", "Top stories, all of them"),
    ("search", "Search every story"),
    ("following", "Follow what matters"),
]


def build_screenshots() -> None:
    print("Phone screenshots")
    phone_w, phone_h = 1080, 1920
    for index, (name, caption) in enumerate(SCREENSHOTS, start=1):
        capture = CAPTURES / f"{name}.png"
        source = capture if capture.exists() else GOLDENS / f"{name}.png"
        if not source.exists():
            print(f"  skipping {name}: no source")
            continue

        screen = Image.open(source).convert("RGB")
        band = 190
        usable = phone_h - band - 40
        scale = usable / screen.height
        resized = screen.resize(
            (int(screen.width * scale), usable), Image.LANCZOS
        )

        frame = Image.new("RGB", (phone_w, phone_h), CANVAS)
        draw = ImageDraw.Draw(frame)
        draw.rectangle((0, 0, phone_w, band), fill=BLACK)
        draw.rounded_rectangle((56, 68, 74, 122), radius=8, fill=BLUE)
        draw.text(
            (96, 72),
            caption,
            font=font(52, weight=700),
            fill=WHITE,
        )
        x = (phone_w - resized.width) // 2
        # Soft edge so the capture does not float on a flat grey field.
        shadow = Image.new("RGBA", (resized.width + 40, resized.height + 40), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            (0, 0, shadow.width - 1, shadow.height - 1), radius=28, fill=(0, 0, 0, 38)
        )
        frame.paste(shadow, (x - 20, band + 30), shadow)
        frame.paste(resized, (x, band + 10))
        save(frame, STORE / "screenshots" / f"phone-{index:02d}-{name}.png")


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
