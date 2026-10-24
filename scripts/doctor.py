"""只读检查本地环境，不安装依赖、不调用聊天模型。"""

import io
import sys
from pathlib import Path

if sys.platform == "win32":
    for stream in (sys.stdout, sys.stderr):
        if isinstance(stream, io.TextIOWrapper):
            try:
                stream.reconfigure(encoding="utf-8")
            except Exception:
                pass


def main() -> None:
    """复用标准库引导检查，无需预先激活虚拟环境。"""
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from scripts.development.environment import main as prepare

    prepare("doctor")


if __name__ == "__main__":
    main()
