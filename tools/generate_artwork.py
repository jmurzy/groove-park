#!/usr/bin/env python3
"""Generate shippable Polycade AGS artwork from artwork/heavenly.webp.

Targets (see plans/WINDOWS-INSTALL.md):
  header.png  460x215   library tile
  hero.png    1920x1080 detail view
  marquee.png 1920x360  digital marquee

Technique:
  - hero: blurred cover background + full-source contain foreground (portrait
    source stays fully visible, sides filled cinematically).
  - header/marquee (wide banners): sharp cover crop focused on the gondola
    cabin band so the "Heavenly" livery stays legible at wide aspect ratios.
  - Every file gets its own filename + dimensions embedded in a pill so you
    can tell on the cabinet which file AGS actually loaded.

Usage:
  python3 tools/generate_artwork.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "artwork" / "heavenly.webp"
OUT_DIR = ROOT / "artwork" / "export"

TARGETS = [
    # (filename, width, height, mode)
    ("header.png", 460, 215, "banner"),
    ("hero.png", 1920, 1080, "contain"),
    ("marquee.png", 1920, 360, "marquee"),
]

# Fraction down the source image to center wide banner crops on. The red
# cabin with the "Heavenly" livery sits around 0.60-0.70 of the portrait
# source, so center there to keep the livery legible at wide aspect ratios.
BANNER_SOURCE_FOCUS_Y = 0.64


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in (
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ):
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default(size=size)


def cover_crop(img: Image.Image, w: int, h: int, focus_y: float = 0.5) -> Image.Image:
    scale = max(w / img.width, h / img.height)
    resized = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    x0 = (resized.width - w) // 2
    if focus_y < 0:
        # Negative focus centers on a fraction down the *source* image so the
        # same subject stays centered across different target aspect ratios.
        # Encoded as -(source_fraction), e.g. -0.64.
        src_center = -focus_y * resized.height
        y0 = round(src_center - h / 2)
    else:
        y_avail = resized.height - h
        y0 = round(y_avail * max(0.0, min(1.0, focus_y)))
    y0 = max(0, min(resized.height - h, y0))
    return resized.crop((x0, y0, x0 + w, y0 + h))


def contain_on_blur(src: Image.Image, w: int, h: int) -> Image.Image:
    bg = cover_crop(src, w, h, 0.5).filter(ImageFilter.GaussianBlur(radius=max(18, w // 70)))
    # Darken slightly so the sharp foreground pops.
    dark = Image.new("RGB", bg.size, (4, 10, 28))
    bg = Image.blend(bg, dark, 0.28)

    scale = min(w / src.width, h / src.height)
    # Leave a small margin so the full gondola breathes inside the frame.
    scale *= 0.96
    fg = src.resize((round(src.width * scale), round(src.height * scale)), Image.LANCZOS)

    # Soft drop shadow.
    shadow_pad = 24
    shadow = Image.new("RGBA", (fg.width + shadow_pad * 2, fg.height + shadow_pad * 2), (0, 0, 0, 0))
    mask = Image.new("L", fg.size, 180)
    shadow.paste(Image.new("RGBA", fg.size, (0, 0, 0, 255)), (shadow_pad, shadow_pad), mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=18))

    canvas = bg.convert("RGBA")
    canvas.alpha_composite(shadow, ((w - shadow.width) // 2, (h - shadow.height) // 2))
    canvas.alpha_composite(fg.convert("RGBA"), ((w - fg.width) // 2, (h - fg.height) // 2))
    return canvas.convert("RGB")


def embed_filename_label(img: Image.Image, filename: str, corner: str = "bl") -> Image.Image:
    w, h = img.size
    label = f"{filename}  •  {w}x{h}"
    # Scale type with output size so the pill stays legible on tiles and heroes alike.
    font_size = max(13, min(44, round(h * 0.075)))
    font = load_font(font_size)
    pad_x = round(font_size * 0.7)
    pad_y = round(font_size * 0.45)

    draw_tmp = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    bbox = draw_tmp.textbbox((0, 0), label, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]

    pill_w, pill_h = tw + pad_x * 2, th + pad_y * 2
    margin = max(8, round(min(w, h) * 0.03))
    pill_y0 = h - pill_h - margin
    if corner == "br":
        pill_x0 = w - pill_w - margin
    else:
        pill_x0 = margin

    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    odraw.rounded_rectangle(
        [pill_x0, pill_y0, pill_x0 + pill_w, pill_y0 + pill_h],
        radius=pill_h // 2,
        fill=(0, 0, 0, 165),
    )
    out = img.convert("RGBA")
    out.alpha_composite(overlay)
    draw = ImageDraw.Draw(out)
    draw.text((pill_x0 + pad_x - bbox[0], pill_y0 + pad_y - bbox[1]), label, font=font, fill=(255, 255, 255, 255))
    return out.convert("RGB")


def build_marquee(src: Image.Image, w: int, h: int) -> Image.Image:
    """Ultra-wide marquee: sky gradient, gondola photo-card left, big title.

    A pure cover crop at 1920x360 from a portrait source only shows a ~140px
    vertical slice, clipping the livery. Instead compose a proper banner.
    """
    # Sky gradient sampled from the reference (deep blue -> lighter horizon).
    top = (8, 92, 188)
    bottom = (64, 160, 225)
    bg = Image.new("RGB", (w, h))
    for y in range(h):
        t = y / max(1, h - 1)
        bg.paste(tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)), (0, y, w, y + 1))
    canvas = bg.convert("RGBA")

    # Sharp gondola photo-card on the left, nearly full marquee height.
    fg_h = round(h * 2.6)
    fg = src.resize((round(src.width * fg_h / src.height), fg_h), Image.LANCZOS)
    focus_px = round(fg_h * BANNER_SOURCE_FOCUS_Y)
    y0 = max(0, min(fg_h - h, focus_px - h // 2))
    fg_band = fg.crop((0, y0, fg.width, y0 + h))
    band_h = h - 36
    band_w = round(fg_band.width * band_h / fg_band.height)
    max_band_w = round(w * 0.34)
    if band_w > max_band_w:
        band_w = max_band_w
        band_h = round(fg_band.height * band_w / fg_band.width)
    fg_band = fg_band.resize((band_w, band_h), Image.LANCZOS)

    # Rounded corners + white border so the card edge looks intentional.
    radius = 22
    mask = Image.new("L", (band_w, band_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, band_w, band_h], radius=radius, fill=255)
    border = Image.new("RGBA", (band_w + 12, band_h + 12), (255, 255, 255, 255))
    border_mask = Image.new("L", (band_w + 12, band_h + 12), 0)
    ImageDraw.Draw(border_mask).rounded_rectangle(
        [0, 0, band_w + 12, band_h + 12], radius=radius + 6, fill=255
    )
    card = Image.new("RGBA", (band_w + 12, band_h + 12), (0, 0, 0, 0))
    card.paste(border, (0, 0), border_mask)
    card.paste(fg_band.convert("RGBA"), (6, 6), mask)

    shadow = Image.new("RGBA", (card.width + 40, card.height + 40), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [20, 20, 20 + card.width, 20 + card.height], radius=radius + 6, fill=(0, 0, 0, 160)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=14))
    gx, gy = 56, (h - card.height) // 2
    canvas.alpha_composite(shadow, (gx - 20, gy - 20))
    canvas.alpha_composite(card, (gx, gy))

    draw = ImageDraw.Draw(canvas)
    title_x = gx + card.width + 70
    title_font = load_font(132)
    sub_font = load_font(36)
    sub = "LAKE TAHOE  •  GONDOLA 2"
    draw.text((title_x + 4, 48), sub, font=sub_font, fill=(255, 255, 255, 235))
    title = "HEAVENLY"
    # Stack below subtitle with measured spacing.
    sb = draw.textbbox((0, 0), sub, font=sub_font)
    tb = draw.textbbox((0, 0), title, font=title_font)
    title_y = 48 + (sb[3] - sb[1]) + 18
    # Keep title inside the frame.
    title_y = min(title_y, h - (tb[3] - tb[1]) - 24)
    draw.text((title_x + 7, title_y + 7), title, font=title_font, fill=(150, 10, 20, 255))
    draw.text((title_x, title_y), title, font=title_font, fill=(255, 255, 255, 255))
    out = canvas.convert("RGB")
    return embed_filename_label(out, "marquee.png", corner="br")


def build(target: str, w: int, h: int, mode: str, src: Image.Image) -> Image.Image:
    if mode == "contain":
        img = contain_on_blur(src, w, h)
        return embed_filename_label(img, target)
    if mode == "marquee":
        return build_marquee(src, w, h)  # already labeled bottom-right
    img = cover_crop(src, w, h, -BANNER_SOURCE_FOCUS_Y)
    return embed_filename_label(img, target)


def main() -> int:
    if not SRC.exists():
        print(f"missing reference: {SRC}", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    src = Image.open(SRC).convert("RGB")
    print(f"reference: {SRC.name} {src.width}x{src.height}")
    for filename, w, h, mode in TARGETS:
        img = build(filename, w, h, mode, src)
        dest = OUT_DIR / filename
        img.save(dest, "PNG")
        print(f"wrote {dest.relative_to(ROOT)} {w}x{h} ({mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
