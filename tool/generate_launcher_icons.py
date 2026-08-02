from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]

GOLD = (216, 177, 78, 255)
GOLD_DARK = (169, 125, 42, 255)
LEAF_GREEN = (70, 111, 105, 255)
LEAF_GREEN_DARK = (45, 78, 73, 255)
CREAM = (255, 252, 242, 255)
COCOA = (42, 25, 18, 255)
BLACK = (7, 8, 7, 255)

ANDROID_ICONS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

ANDROID_LAUNCH_IMAGES = {
    "mipmap-mdpi": 96,
    "mipmap-hdpi": 144,
    "mipmap-xhdpi": 192,
    "mipmap-xxhdpi": 288,
    "mipmap-xxxhdpi": 384,
}

ANDROID_ADAPTIVE_FOREGROUND = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

IOS_ICON_FILES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def cubic(p0, p1, p2, p3, steps=36):
    points = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        points.append((x, y))
    return points


def pod_outline(size: int, scale: float = 1.0, dy: float = 0.0):
    cx = size * 0.5
    top = size * (0.18 + dy)
    bottom = size * (0.86 + dy)
    left = cubic(
        (cx, top),
        (size * 0.18, size * (0.25 + dy)),
        (size * 0.18, size * (0.67 + dy)),
        (cx, bottom),
    )
    right = cubic(
        (cx, bottom),
        (size * 0.83, size * (0.67 + dy)),
        (size * 0.82, size * (0.25 + dy)),
        (cx, top),
    )
    pts = left + right
    if scale == 1.0:
        return pts
    return [
        (cx + (x - cx) * scale, size * 0.52 + (y - size * 0.52) * scale)
        for x, y in pts
    ]


def draw_leaf(draw: ImageDraw.ImageDraw, size: int):
    stem = [
        (size * 0.49, size * 0.21),
        (size * 0.43, size * 0.12),
        (size * 0.39, size * 0.07),
    ]
    draw.line(stem, fill=LEAF_GREEN, width=max(9, size // 38), joint="curve")
    leaf = cubic(
        (size * 0.46, size * 0.15),
        (size * 0.55, size * 0.08),
        (size * 0.69, size * 0.1),
        (size * 0.74, size * 0.17),
        20,
    ) + cubic(
        (size * 0.74, size * 0.17),
        (size * 0.63, size * 0.25),
        (size * 0.52, size * 0.22),
        (size * 0.46, size * 0.15),
        20,
    )
    draw.polygon(leaf, fill=LEAF_GREEN)
    draw.line(
        [(size * 0.5, size * 0.17), (size * 0.68, size * 0.17)],
        fill=LEAF_GREEN_DARK,
        width=max(2, size // 120),
    )


def draw_chocolate_tile(draw: ImageDraw.ImageDraw, size: int):
    radius = size * 0.36
    cx, cy = size * 0.5, size * 0.54
    for y in range(-2, 4):
        for x in range(-2, 4):
            px = cx + x * radius * 0.5 - y * radius * 0.08
            py = cy + y * radius * 0.33
            alpha = 34 if (x + y) % 2 == 0 else 20
            color = (92, 54, 34, alpha)
            rect = [px - radius * 0.24, py - radius * 0.14, px + radius * 0.22, py + radius * 0.12]
            draw.rounded_rectangle(rect, radius=size * 0.035, fill=color, outline=(143, 91, 53, alpha + 10), width=1)


def make_mark(size: int = 1024, *, transparent: bool = True, with_background: bool = False) -> Image.Image:
    scale = 4
    big = size * scale
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0) if transparent else BLACK)
    draw = ImageDraw.Draw(image, "RGBA")

    if with_background:
        draw_chocolate_tile(draw, big)
        draw.ellipse(
            [big * 0.055, big * 0.055, big * 0.945, big * 0.945],
            fill=(8, 9, 8, 245),
            outline=(216, 177, 78, 165),
            width=big // 70,
        )

    pod = pod_outline(big, scale=0.78, dy=0.03)
    halo = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    halo_draw = ImageDraw.Draw(halo, "RGBA")
    halo_draw.line(pod + [pod[0]], fill=(216, 177, 78, 180), width=big // 24, joint="curve")
    halo = halo.filter(ImageFilter.GaussianBlur(big * 0.018))
    image.alpha_composite(halo)

    draw_leaf(draw, big)

    inner = pod_outline(big, scale=0.56, dy=0.035)
    draw.polygon(inner, fill=CREAM)

    draw.line(pod + [pod[0]], fill=GOLD_DARK, width=big // 18, joint="curve")
    draw.line(pod + [pod[0]], fill=GOLD, width=big // 26, joint="curve")

    stripe_width = max(16, big // 38)
    stripes = [
        [(big * 0.40, big * 0.31), (big * 0.52, big * 0.49), (big * 0.42, big * 0.69)],
        [(big * 0.56, big * 0.30), (big * 0.68, big * 0.50), (big * 0.58, big * 0.70)],
    ]
    for stripe in stripes:
        draw.line(stripe, fill=LEAF_GREEN, width=stripe_width, joint="curve")
        draw.line(stripe, fill=(255, 255, 255, 34), width=max(2, stripe_width // 6), joint="curve")

    # Subtle internal grain nodes, visible only at larger sizes.
    node_radius = max(3, big // 70)
    for i, (x, y) in enumerate(
        [
            (big * 0.45, big * 0.40),
            (big * 0.54, big * 0.48),
            (big * 0.45, big * 0.58),
            (big * 0.57, big * 0.64),
        ]
    ):
        draw.ellipse(
            [x - node_radius, y - node_radius, x + node_radius, y + node_radius],
            fill=(245, 244, 236, 190),
        )
        if i:
            px, py = [(big * 0.45, big * 0.40), (big * 0.54, big * 0.48), (big * 0.45, big * 0.58)][i - 1]
            draw.line([(px, py), (x, y)], fill=(216, 177, 78, 95), width=max(1, big // 180))

    small = image.resize((size, size), Image.Resampling.LANCZOS)
    return small


def save_png(image: Image.Image, path: Path, *, remove_alpha: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    output = image.convert("RGB") if remove_alpha else image
    output.save(path, "PNG", optimize=True)


def fit_square(source: Image.Image, size: int, background=BLACK, padding=0.08) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), background)
    content_size = int(size * (1 - padding * 2))
    fitted = ImageOps.contain(source, (content_size, content_size), Image.Resampling.LANCZOS)
    canvas.alpha_composite(fitted, ((size - fitted.width) // 2, (size - fitted.height) // 2))
    return canvas


def main() -> None:
    transparent_mark = make_mark(1024, transparent=True, with_background=False)
    splash_mark = make_mark(1024, transparent=True, with_background=False)
    launcher_source = make_mark(1024, transparent=False, with_background=True)

    for name in ("conkkao_icon.png", "cubnex_icon.png"):
        save_png(transparent_mark, ROOT / "assets" / "icons" / name)

    save_png(splash_mark, ROOT / "assets" / "icons" / "conkkao_splash_icon.png")

    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, size in ANDROID_ICONS.items():
        save_png(fit_square(launcher_source, size, padding=0.0), android_res / folder / "ic_launcher.png")

    for folder, size in ANDROID_ADAPTIVE_FOREGROUND.items():
        save_png(fit_square(transparent_mark, size, background=(0, 0, 0, 0), padding=0.08), android_res / folder / "ic_launcher_foreground.png")

    for folder, size in ANDROID_LAUNCH_IMAGES.items():
        save_png(fit_square(splash_mark, size, background=(0, 0, 0, 0), padding=0.07), android_res / folder / "launch_image.png")

    ios_icons = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for filename, size in IOS_ICON_FILES.items():
        save_png(fit_square(launcher_source, size, padding=0.0), ios_icons / filename, remove_alpha=True)

    ios_launch = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    for filename, size in {
        "LaunchImage.png": 160,
        "LaunchImage@2x.png": 320,
        "LaunchImage@3x.png": 480,
    }.items():
        save_png(fit_square(splash_mark, size, background=(0, 0, 0, 0), padding=0.06), ios_launch / filename)

    print("ConKkao launcher, splash and Flutter icon assets generated.")


if __name__ == "__main__":
    main()
