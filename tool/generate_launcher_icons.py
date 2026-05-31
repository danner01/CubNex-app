from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(
    r"C:\Users\Dann\.codex\generated_images\019ddbdf-fedb-71b0-b120-fead33fc9256\ig_0cf6127d082de290016a1c96799ac8819199276853ed0f2ab0.png"
)


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


def fit_square(source: Image.Image, size: int, background=(9, 10, 9, 255), padding=0.0) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), background)
    content_size = int(size * (1 - padding * 2))
    fitted = ImageOps.contain(source, (content_size, content_size), Image.Resampling.LANCZOS)
    x = (size - fitted.width) // 2
    y = (size - fitted.height) // 2
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def circular_icon(source: Image.Image, size: int, padding=0.0) -> Image.Image:
    icon = fit_square(source, size, background=(0, 0, 0, 0), padding=padding)
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    inset = int(size * padding)
    draw.ellipse((inset, inset, size - inset, size - inset), fill=255)
    icon.putalpha(mask)
    return icon


def save_png(image: Image.Image, path: Path, *, remove_alpha: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    output = image.convert("RGB") if remove_alpha else image
    output.save(path, "PNG", optimize=True)


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(f"No existe la imagen fuente: {SOURCE}")

    source = Image.open(SOURCE).convert("RGBA")

    # Internal Flutter asset used in docs/login references.
    save_png(
        circular_icon(source, 1024, padding=0.01),
        ROOT / "assets" / "icons" / "cubnex_icon.png",
    )

    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, size in ANDROID_ICONS.items():
        save_png(
            fit_square(source, size, padding=0.0),
            android_res / folder / "ic_launcher.png",
        )

    for folder, size in ANDROID_LAUNCH_IMAGES.items():
        save_png(
            circular_icon(source, size, padding=0.04),
            android_res / folder / "launch_image.png",
        )

    ios_icons = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for filename, size in IOS_ICON_FILES.items():
        save_png(
            fit_square(source, size, padding=0.0),
            ios_icons / filename,
            remove_alpha=True,
        )

    ios_launch = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    for filename, size in {
        "LaunchImage.png": 160,
        "LaunchImage@2x.png": 320,
        "LaunchImage@3x.png": 480,
    }.items():
        save_png(
            circular_icon(source, size, padding=0.06),
            ios_launch / filename,
        )

    print("Launcher icons generated from", SOURCE)


if __name__ == "__main__":
    main()
