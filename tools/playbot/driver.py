"""Speaks the newline-JSON protocol in scripts/bot_api.gd to a headless game."""
from __future__ import annotations
import json
import subprocess
import threading
import queue
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path("C:/Users/Admin/dev/tools/godot/bin/Godot_v4.3-stable_win64_console.exe")
MARK = "@@BOT@@ "


class GameError(RuntimeError):
    pass


class Game:
    """One headless Cattle Trail process the bot can play."""

    def __init__(self, godot: Path = GODOT, root: Path = ROOT, timeout: float = 60.0):
        self.timeout = timeout
        self.engine_log: list[str] = []
        # Counts only the things a person does with their hands: a verb pressed
        # or a place clicked. Observing and letting frames run are free, so a
        # stage's cost reads as effort rather than as how long the bot looped.
        self.action_count = 0
        self.proc = subprocess.Popen(
            [str(godot), "--headless", "--path", str(root), "--", "--bot"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace", bufsize=1, cwd=str(root),
        )
        self._lines: queue.Queue = queue.Queue()
        self._reader = threading.Thread(target=self._drain, daemon=True)
        self._reader.start()
        hello = self._read()
        if hello.get("type") != "hello":
            raise GameError(f"expected hello, got {hello}")

    def _drain(self) -> None:
        assert self.proc.stdout is not None
        for raw in self.proc.stdout:
            line = raw.rstrip("\r\n")
            if line.startswith(MARK):
                self._lines.put(line[len(MARK):])
            elif line.strip():
                # Engine noise. Kept, because a SCRIPT ERROR here is itself a finding.
                self.engine_log.append(line)
        self._lines.put(None)

    def _read(self) -> dict:
        try:
            payload = self._lines.get(timeout=self.timeout)
        except queue.Empty:
            raise GameError(f"game went silent for {self.timeout}s")
        if payload is None:
            raise GameError("game exited\n" + "\n".join(self.engine_log[-15:]))
        return json.loads(payload)

    def send(self, **command) -> dict:
        if self.proc.poll() is not None:
            raise GameError("game already exited\n" + "\n".join(self.engine_log[-15:]))
        assert self.proc.stdin is not None
        self.proc.stdin.write(json.dumps(command) + "\n")
        self.proc.stdin.flush()
        return self._read()

    # The verbs a player has.
    def observe(self) -> dict:
        return self.send(cmd="obs")

    def act(self, name: str) -> dict:
        self.action_count += 1
        return self.send(cmd="act", name=name)

    def move(self, x: float, y: float) -> dict:
        self.action_count += 1
        return self.send(cmd="move", x=x, y=y)

    def step(self, frames: int = 6) -> dict:
        return self.send(cmd="step", frames=frames)

    def options(self) -> dict:
        return self.send(cmd="options")

    def choose(self, option: str) -> dict:
        return self.send(cmd="choose", option=option)

    def speed(self, scale: float) -> dict:
        return self.send(cmd="speed", scale=scale)

    def errors(self) -> list[str]:
        return [l for l in self.engine_log if "SCRIPT ERROR" in l or l.startswith("ERROR:")]

    def close(self) -> None:
        try:
            if self.proc.poll() is None:
                self.send(cmd="quit")
        except Exception:
            pass
        try:
            self.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.proc.kill()
