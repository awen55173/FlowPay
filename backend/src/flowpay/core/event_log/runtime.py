# 打开事件存储，并在服务生命周期内持有运行锁。
from __future__ import annotations

import os
from collections.abc import Generator
from contextlib import contextmanager

from flowpay.core.config import Settings
from flowpay.core.event_log import EventStore, EventStoreProtocol

if os.name == "nt":
    import msvcrt
else:
    import fcntl


@contextmanager
def open_store(settings: Settings) -> Generator[EventStoreProtocol]:
    """打开事件存储，并在整个使用区间持有运行锁。

    锁跟随本地文件句柄，用于防止同时启动两个管理器恢复或调度同一份会话，
    不是每次查询的锁。必须在退出此上下文前完成后台任务关闭，否则存储可能先于任务释放。
    """
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    with (settings.data_dir / "runtime.lock").open("a+b") as lock:
        try:
            if os.name == "nt":
                lock.seek(0, os.SEEK_END)
                if lock.tell() == 0:
                    lock.write(b"\0")
                    lock.flush()
                lock.seek(0)
                msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (BlockingIOError, OSError) as error:
            raise RuntimeError("This data directory already has a running backend") from error
        yield EventStore(settings.data_dir / "sessions.sqlite")
