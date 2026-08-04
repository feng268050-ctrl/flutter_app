#!/usr/bin/env python3
"""Interactive hex serial console with a fixed TX input bar (curses + pyserial).

RX: hex bytes, one line per idle gap (approx. one UART/Modbus burst).
TX: bottom input bar — type hex (spaces/0x ok), Enter to send.
Quit: Ctrl+C, Esc, or :q / quit / exit in the TX bar.
"""
from __future__ import annotations

import argparse
import curses
import re
import sys
import threading
import time
from collections import deque
from datetime import datetime
from pathlib import Path
from typing import Deque, List, Optional, TextIO, Any

import serial

_HEX_STRIP = re.compile(r"(?i)0x|[^0-9a-fA-F]")


def parse_hex_line(text: str) -> bytes:
    cleaned = text.strip()
    if not cleaned:
        return b""
    joined = _HEX_STRIP.sub("", cleaned)
    if not joined:
        raise ValueError("no hex bytes found")
    if len(joined) % 2 != 0:
        raise ValueError("odd number of hex digits")
    return bytes.fromhex(joined)


def parity_const(name: str) -> str:
    key = name.strip().lower()
    table = {
        "none": serial.PARITY_NONE,
        "even": serial.PARITY_EVEN,
        "odd": serial.PARITY_ODD,
        "mark": serial.PARITY_MARK,
        "space": serial.PARITY_SPACE,
    }
    if key not in table:
        raise ValueError(f"unsupported parity: {name}")
    return table[key]


def stopbits_const(n: float) -> float:
    if n in (1, 1.0):
        return serial.STOPBITS_ONE
    if n in (2, 2.0):
        return serial.STOPBITS_TWO
    if n in (1.5,):
        return serial.STOPBITS_ONE_POINT_FIVE
    raise ValueError(f"unsupported stop bits: {n}")


class HexConsole:
    def __init__(
        self,
        port: str,
        baud: int,
        *,
        data_bits: int = 8,
        parity: str = "none",
        stop_bits: float = 1,
        idle_ms: float = 5.0,
        log_path: Optional[str] = None,
        log_append: bool = False,
        mode: str = "RS485",
    ) -> None:
        self.port = port
        self.baud = baud
        self.idle_s = max(idle_ms, 0.5) / 1000.0
        self.mode = mode
        self._rx_lines: Deque[str] = deque(maxlen=2000)
        self._status = ""
        self._tx_buf = ""
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._log: Optional[TextIO] = None
        if log_path:
            path = Path(log_path)
            path.parent.mkdir(parents=True, exist_ok=True)
            self._log = path.open("a" if log_append else "w", encoding="utf-8")

        self.ser = serial.Serial(
            port=port,
            baudrate=baud,
            bytesize=data_bits,
            parity=parity_const(parity),
            stopbits=stopbits_const(stop_bits),
            timeout=0.02,
            write_timeout=1.0,
        )

    def close(self) -> None:
        self._stop.set()
        try:
            self.ser.close()
        except Exception:
            pass
        if self._log is not None:
            try:
                self._log.close()
            except Exception:
                pass

    def _append_line(self, line: str) -> None:
        with self._lock:
            self._rx_lines.append(line)
        if self._log is not None:
            self._log.write(line + "\n")
            self._log.flush()

    def _rx_loop(self) -> None:
        buf = bytearray()
        last_rx = 0.0
        while not self._stop.is_set():
            try:
                chunk = self.ser.read(256)
            except serial.SerialException as exc:
                self._status = f"RX error: {exc}"
                self._stop.set()
                break
            now = time.monotonic()
            if chunk:
                if not buf:
                    last_rx = now
                buf.extend(chunk)
                last_rx = now
            elif buf and (now - last_rx) >= self.idle_s:
                ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]
                hex_body = " ".join(f"{b:02X}" for b in buf)
                self._append_line(f"[{ts}] RX {hex_body}")
                buf.clear()
            else:
                time.sleep(0.001)

        if buf:
            ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            hex_body = " ".join(f"{b:02X}" for b in buf)
            self._append_line(f"[{ts}] RX {hex_body}")

    def _send_hex(self, text: str) -> None:
        try:
            payload = parse_hex_line(text)
        except ValueError as exc:
            self._status = f"TX parse error: {exc}"
            return
        if not payload:
            return
        try:
            self.ser.write(payload)
            self.ser.flush()
        except serial.SerialException as exc:
            self._status = f"TX error: {exc}"
            return
        ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        hex_body = " ".join(f"{b:02X}" for b in payload)
        self._append_line(f"[{ts}] TX {hex_body}")
        self._status = f"sent {len(payload)} byte(s)"

    def _draw(self, stdscr: Any) -> None:
        stdscr.erase()
        height, width = stdscr.getmaxyx()
        if height < 5 or width < 20:
            stdscr.addstr(0, 0, "terminal too small")
            stdscr.refresh()
            return

        header = (
            f"serial-hex-console  {self.port}  MODE={self.mode}  "
            f"{self.baud} baud  idle={self.idle_s * 1000:.0f}ms  "
            f"quit: Esc/:q"
        )
        stdscr.addnstr(0, 0, header.ljust(width)[: width - 1], width - 1, curses.A_REVERSE)

        status_row = height - 2
        input_row = height - 1
        rx_top = 1
        rx_bottom = status_row - 1
        rx_h = max(rx_bottom - rx_top + 1, 1)

        with self._lock:
            lines: List[str] = list(self._rx_lines)
        view = lines[-rx_h:] if len(lines) > rx_h else lines
        for i, line in enumerate(view):
            stdscr.addnstr(rx_top + i, 0, line[: width - 1], width - 1)

        status = self._status or "type hex in TX bar, Enter to send (spaces/0x ok)"
        stdscr.addnstr(status_row, 0, status.ljust(width)[: width - 1], width - 1, curses.A_DIM)

        prompt = "TX> "
        room = max(width - len(prompt) - 1, 8)
        shown = self._tx_buf[-(room):]
        stdscr.addnstr(input_row, 0, (prompt + shown).ljust(width)[: width - 1], width - 1)
        stdscr.move(input_row, min(len(prompt) + len(shown), width - 2))
        stdscr.refresh()

    def run(self, stdscr: Any) -> None:
        curses.curs_set(1)
        stdscr.nodelay(True)
        stdscr.keypad(True)
        stdscr.timeout(50)

        rx_thread = threading.Thread(target=self._rx_loop, name="serial-rx", daemon=True)
        rx_thread.start()

        while not self._stop.is_set():
            self._draw(stdscr)
            try:
                ch = stdscr.get_wch()
            except curses.error:
                continue

            if ch == curses.KEY_RESIZE:
                continue
            if ch in ("\x1b",):  # Esc
                break
            if ch in ("\x03",):  # Ctrl+C
                break
            if ch in ("\n", "\r", curses.KEY_ENTER):
                cmd = self._tx_buf.strip()
                self._tx_buf = ""
                if cmd.lower() in {":q", "quit", "exit", ":quit"}:
                    break
                if cmd:
                    self._send_hex(cmd)
                continue
            if ch in (curses.KEY_BACKSPACE, "\x7f", "\b"):
                self._tx_buf = self._tx_buf[:-1]
                continue
            if isinstance(ch, str) and ch.isprintable():
                if len(self._tx_buf) < 4096:
                    self._tx_buf += ch

        self._stop.set()
        rx_thread.join(timeout=1.0)


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("port")
    p.add_argument("--baud", type=int, default=115200)
    p.add_argument("--mode", default="RS485")
    p.add_argument("--data-bits", type=int, default=8)
    p.add_argument("--parity", default="none")
    p.add_argument("--stop-bits", type=float, default=1)
    p.add_argument("--idle-ms", type=float, default=5.0)
    p.add_argument("--log")
    p.add_argument("--log-append", action="store_true")
    return p


def main(argv: Optional[List[str]] = None) -> int:
    args = build_arg_parser().parse_args(argv)
    console = HexConsole(
        args.port,
        args.baud,
        data_bits=args.data_bits,
        parity=args.parity,
        stop_bits=args.stop_bits,
        idle_ms=args.idle_ms,
        log_path=args.log,
        log_append=args.log_append,
        mode=args.mode,
    )
    try:
        curses.wrapper(console.run)
    except serial.SerialException as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    finally:
        console.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
