"""Make a review sheet from unchanged Godot capture frames."""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageFont


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1] / 'previews' / 'final')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[4]
    font = ImageFont.truetype(str(project / 'game' / 'assets' / 'fonts' / 'NotoSerifSC-VF.ttf'), 16)
    times = [0.0, 0.3, 0.6, 1.1, 1.8, 3.3, 4.2]
    sheets = []
    for skill in ('ice', 'rock'):
        sheet = Image.new('RGB', (1280, 444), '#0d131e')
        draw = ImageDraw.Draw(sheet)
        draw.text((12, 7), f'{skill.upper()} — Godot timeline samples', font=font, fill='#e4dfce')
        for index, time in enumerate(times):
            frame = round(time * 30)
            with Image.open(args.root / skill / f'frame_{frame:04d}.png') as source:
                thumbnail = source.convert('RGB').resize((320, 180), Image.Resampling.LANCZOS)
            x = (index % 4) * 320
            y = (index // 4) * 206 + 32
            sheet.paste(thumbnail, (x, y))
            draw.text((x + 8, y + 180), f'{time:.1f} s', font=font, fill='#c3dce9')
        path = args.root / f'{skill}_timeline.jpg'
        sheet.save(path, quality=94)
        sheets.append(sheet)
        print(path)
    combined = Image.new('RGB', (1280, 888), '#0d131e')
    combined.paste(sheets[0], (0, 0))
    combined.paste(sheets[1], (0, 444))
    path = args.root / 'elemental_timeline.jpg'
    combined.save(path, quality=94)
    print(path)


if __name__ == '__main__':
    main()
