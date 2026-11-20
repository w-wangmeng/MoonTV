"""Generate abstract test artwork for the local mock media server."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(__file__).with_name("mock_art")
OUT.mkdir(exist_ok=True)

FONT_PATHS = [
    Path(r"C:\Windows\Fonts\msyh.ttc"),
    Path(r"C:\Windows\Fonts\msyhbd.ttc"),
]


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_PATHS:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def art(name: str, title: str, kind: str, colors, wide: bool):
    width, height = (1600, 900) if wide else (640, 960)
    base = Image.new("RGB", (width, height), colors[0])
    draw = ImageDraw.Draw(base)
    for y in range(height):
        t = y / max(1, height - 1)
        c = tuple(
            int(colors[0][i] * (1 - t) + colors[1][i] * t)
            for i in range(3)
        )
        draw.line([(0, y), (width, y)], fill=c)

    random.seed(name)
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for _ in range(18):
        r = random.randint(40, 300)
        x = random.randint(-100, width)
        y = random.randint(-100, height)
        alpha = random.randint(12, 45)
        gd.ellipse(
            [x - r, y - r, x + r, y + r],
            fill=(random.randint(40, 120), random.randint(130, 220), 255, alpha),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    base = Image.alpha_composite(base.convert("RGBA"), glow)

    draw = ImageDraw.Draw(base)
    # Orbit lines and a moon-like disc.
    cx = int(width * 0.72)
    cy = int(height * 0.32)
    for scale in (0.58, 0.8, 1.0):
        rx = int(width * 0.33 * scale)
        ry = int(height * 0.18 * scale)
        draw.ellipse(
            [cx - rx, cy - ry, cx + rx, cy + ry],
            outline=(150, 220, 255, 30),
            width=2,
        )
    disc_r = int(min(width, height) * 0.12)
    draw.ellipse(
        [cx - disc_r, cy - disc_r, cx + disc_r, cy + disc_r],
        fill=(255, 255, 255, 235),
    )
    draw.ellipse(
        [cx - disc_r * 0.45, cy - disc_r * 0.7, cx + disc_r * 0.75, cy + disc_r * 0.35],
        fill=(18, 32, 58, 80),
    )

    # Film perforation strip.
    strip_x = 42 if not wide else 56
    for y in range(100, height - 100, 54):
        draw.rounded_rectangle(
            [strip_x, y, strip_x + 24, y + 24],
            radius=5,
            outline=(255, 255, 255, 45),
            width=2,
        )

    # Typography.
    small = font(20 if wide else 18)
    big = font(74 if wide else 64)
    body = font(28 if wide else 26)
    draw.text(
        (strip_x + 56, height - (170 if wide else 220)),
        kind.upper(),
        font=small,
        fill=(120, 215, 255, 220),
    )
    draw.text(
        (strip_x + 52, height - (145 if wide else 195)),
        title,
        font=big,
        fill=(255, 255, 255, 245),
    )
    draw.text(
        (strip_x + 56, height - (60 if wide else 90)),
        "MOONBOX · TEST LIBRARY",
        font=small,
        fill=(255, 255, 255, 120),
    )
    draw.text(
        (strip_x + 56, height - (105 if wide else 135)),
        "A quiet night, a good story.",
        font=body,
        fill=(255, 255, 255, 160),
    )

    # Vignette.
    vignette = Image.new("L", (width, height), 0)
    vd = ImageDraw.Draw(vignette)
    vd.ellipse(
        [-width * 0.3, -height * 0.3, width * 1.3, height * 1.3],
        fill=255,
    )
    vignette = vignette.filter(ImageFilter.GaussianBlur(80))
    black = Image.new("RGBA", (width, height), (3, 7, 14, 190))
    base = Image.composite(base, black, vignette)

    target = OUT / f"{name}{'-wide' if wide else ''}.png"
    base.convert("RGB").save(target, quality=92)
    print(target)


if __name__ == "__main__":
    art("movie1", "月光放映室", "Feature Film", [(8, 20, 42), (22, 70, 102)], False)
    art("movie1", "月光放映室", "Feature Film", [(8, 20, 42), (22, 70, 102)], True)
    art("movie2", "第二部测试电影", "Feature Film", [(28, 12, 45), (90, 36, 92)], False)
    art("series", "测试剧集", "Limited Series", [(7, 25, 31), (18, 92, 80)], False)
    art("series", "测试剧集", "Limited Series", [(7, 25, 31), (18, 92, 80)], True)
    art("episode", "测试章节", "Episode 01", [(18, 22, 48), (60, 42, 110)], False)
