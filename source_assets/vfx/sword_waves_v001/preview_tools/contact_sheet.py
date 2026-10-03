"""Review the actual charge, flight and impact frames from the Godot demo."""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageFont


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1] / 'previews' / 'final')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[4]
    font = ImageFont.truetype(str(project / 'game' / 'assets' / 'fonts' / 'NotoSerifSC-VF.ttf'), 16)
    times = [0.0, 0.18, 0.4, 0.65, 0.9, 1.1, 1.4, 2.2]
    sheets = []
    for skill in ('normal', 'frost'):
        sheet = Image.new('RGB', (1280, 444), '#0d131e')
        draw = ImageDraw.Draw(sheet)
        draw.text((12, 7), f'{skill.upper()} — Godot sword wave timeline • nearest 30 fps frame', font=font, fill='#e4dfce')
        for index, time in enumerate(times):
            frame = round(time * 30)
            with Image.open(args.root / skill / f'frame_{frame:04d}.png') as source:
                thumbnail = source.convert('RGB').resize((320, 180), Image.Resampling.LANCZOS)
            x, y = (index % 4) * 320, (index // 4) * 206 + 32
            sheet.paste(thumbnail, (x, y))
            draw.text((x + 8, y + 180), f'{frame / 30:.2f} s', font=font, fill='#c3dce9')
        path = args.root / f'{skill}_timeline.jpg'
        sheet.save(path, quality=94)
        sheets.append(sheet)
        print(path)
    combined = Image.new('RGB', (1280, 888), '#0d131e')
    for index, sheet in enumerate(sheets):
        combined.paste(sheet, (0, index * 444))
    path = args.root / 'sword_wave_timeline.jpg'
    combined.save(path, quality=94)
    print(path)
    comparison = Image.new('RGB', (1920, 582), '#0d131e')
    comparison_draw = ImageDraw.Draw(comparison)
    comparison_font = ImageFont.truetype(str(project / 'game' / 'assets' / 'fonts' / 'NotoSerifSC-VF.ttf'), 24)
    for index, (skill, title) in enumerate((('normal', '月白剑气 / SILVER CRESCENT'), ('frost', '凛冬剑气 / WINTER CRESCENT'))):
        with Image.open(args.root / skill / 'frame_0018.png') as source:
            view = source.convert('RGB').resize((960, 540), Image.Resampling.LANCZOS)
        comparison.paste(view, (index * 960, 42))
        comparison_draw.text((index * 960 + 20, 8), title, font=comparison_font, fill='#e4dfce')
    path = args.root / 'sword_wave_comparison.jpg'
    comparison.save(path, quality=95)
    print(path)


if __name__ == '__main__':
    main()
