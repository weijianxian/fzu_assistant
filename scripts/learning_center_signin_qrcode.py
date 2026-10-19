#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["qrcode[pil]>=8.2,<9"]
# ///
"""学习中心签到码；uv run scripts/learning_center_signin_qrcode.py --watch。

格式参考 fzuhelper-app/scripts/learning_center_signin_qrcode.py。
使用北京时间，生成从当前时刻起一分钟有效的 PNG 和终端二维码。
"""

from __future__ import annotations

import argparse
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import qrcode

CHINA_TIME = timezone(timedelta(hours=8))
DEFAULT_OUTPUT = (
    Path(__file__).resolve().parent.parent / "build" / "learning-center-signin.png"
)


def generate_qr_code(output: Path, *, show_ascii: bool = True) -> str:
    start = datetime.now(CHINA_TIME).replace(microsecond=0)
    end = start + timedelta(minutes=1)
    payload = f"seatSignInCode@{start:%Y-%m-%d %H:%M:%S}@{end:%Y-%m-%d %H:%M:%S}"
    qr = qrcode.QRCode(
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(payload)
    qr.make(fit=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    qr.make_image(fill_color="black", back_color="white").save(output, format="PNG")
    if show_ascii:
        qr.print_ascii(out=sys.stdout, invert=True)
    print(payload)
    print(f"PNG: {output.resolve()}")
    print(f"有效至: {end:%Y-%m-%d %H:%M:%S} (UTC+08:00)", flush=True)
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-o", "--output", type=Path, default=DEFAULT_OUTPUT, help="PNG 输出路径"
    )
    parser.add_argument("--watch", action="store_true", help="持续刷新同一个 PNG 文件")
    parser.add_argument(
        "--interval", type=int, default=30, help="刷新间隔秒数，1–59，默认 30"
    )
    parser.add_argument(
        "--no-ascii", action="store_true", help="仅输出 PNG 和码内容，不绘制终端二维码"
    )
    args = parser.parse_args()
    if not 1 <= args.interval < 60:
        parser.error("--interval 必须在 1–59 秒之间")
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    try:
        while True:
            if args.watch and sys.stdout.isatty():
                print("\033[2J\033[H", end="")
            generate_qr_code(args.output, show_ascii=not args.no_ascii)
            if not args.watch:
                return 0
            time.sleep(args.interval)
    except KeyboardInterrupt:
        return 0
    except OSError as error:
        parser.exit(1, f"无法生成二维码: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
