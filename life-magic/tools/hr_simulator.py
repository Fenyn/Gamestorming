"""
Heart Rate Simulator for Life Magic

Simulates a realistic exercise session over WebSocket.
The game connects to ws://localhost:9876 and receives JSON messages
with heart rate data.

Usage:
    python hr_simulator.py [--port 9876]

The simulation cycles through exercise phases:
    Rest → Warmup → Lifting Set → Rest Between Sets → (repeat) → Cooldown

Press Ctrl+C to stop.
"""

import asyncio
import json
import math
import random
import time
import argparse

import websockets

PORT = 9876

# Exercise phases with target HR ranges and durations
WORKOUT_PHASES = [
    {"name": "REST",           "target_hr": 68,  "variance": 4,  "duration": 30,  "ramp_speed": 0.03},
    {"name": "WARMUP",         "target_hr": 95,  "variance": 5,  "duration": 45,  "ramp_speed": 0.06},
    {"name": "LIFTING SET 1",  "target_hr": 135, "variance": 8,  "duration": 40,  "ramp_speed": 0.10},
    {"name": "REST",           "target_hr": 100, "variance": 5,  "duration": 30,  "ramp_speed": 0.08},
    {"name": "LIFTING SET 2",  "target_hr": 145, "variance": 10, "duration": 35,  "ramp_speed": 0.10},
    {"name": "REST",           "target_hr": 105, "variance": 5,  "duration": 25,  "ramp_speed": 0.08},
    {"name": "LIFTING SET 3",  "target_hr": 155, "variance": 12, "duration": 30,  "ramp_speed": 0.12},
    {"name": "REST",           "target_hr": 110, "variance": 6,  "duration": 30,  "ramp_speed": 0.07},
    {"name": "HEAVY SET",      "target_hr": 170, "variance": 10, "duration": 25,  "ramp_speed": 0.15},
    {"name": "REST",           "target_hr": 115, "variance": 6,  "duration": 35,  "ramp_speed": 0.06},
    {"name": "LIFTING SET 4",  "target_hr": 148, "variance": 10, "duration": 35,  "ramp_speed": 0.10},
    {"name": "COOLDOWN",       "target_hr": 90,  "variance": 5,  "duration": 50,  "ramp_speed": 0.04},
    {"name": "REST",           "target_hr": 72,  "variance": 3,  "duration": 40,  "ramp_speed": 0.03},
]


class HeartRateSimulator:
    def __init__(self):
        self.current_hr = 68.0
        self.phase_index = 0
        self.phase_timer = 0.0
        self.clients = set()

    def get_current_phase(self):
        return WORKOUT_PHASES[self.phase_index % len(WORKOUT_PHASES)]

    def tick(self, dt: float) -> float:
        phase = self.get_current_phase()

        target = phase["target_hr"] + random.gauss(0, phase["variance"] * 0.3)
        self.current_hr += (target - self.current_hr) * phase["ramp_speed"]

        noise = math.sin(time.time() * 0.7) * 1.5 + random.gauss(0, 0.8)
        hr = max(45, self.current_hr + noise)

        self.phase_timer += dt
        if self.phase_timer >= phase["duration"]:
            self.phase_timer = 0.0
            old_name = phase["name"]
            self.phase_index += 1
            new_phase = self.get_current_phase()
            print(f"  Phase: {old_name} -> {new_phase['name']} (target {new_phase['target_hr']} BPM)")

        return round(hr, 1)

    def build_message(self, hr: float) -> str:
        phase = self.get_current_phase()
        return json.dumps({
            "type": "heart_rate",
            "bpm": hr,
            "phase": phase["name"],
            "timestamp": time.time(),
        })


sim = HeartRateSimulator()


async def handler(websocket):
    sim.clients.add(websocket)
    addr = websocket.remote_address
    print(f"[+] Client connected: {addr}")
    try:
        await websocket.wait_closed()
    finally:
        sim.clients.discard(websocket)
        print(f"[-] Client disconnected: {addr}")


async def broadcast_loop():
    print(f"\nStarting workout simulation...")
    phase = sim.get_current_phase()
    print(f"  Phase: {phase['name']} (target {phase['target_hr']} BPM)\n")

    while True:
        hr = sim.tick(0.5)
        if sim.clients:
            msg = sim.build_message(hr)
            await asyncio.gather(
                *[c.send(msg) for c in sim.clients.copy()],
                return_exceptions=True
            )
            phase = sim.get_current_phase()
            print(f"\r  HR: {hr:5.1f} BPM | Phase: {phase['name']:16s} | Clients: {len(sim.clients)}", end="", flush=True)
        else:
            print(f"\r  HR: {hr:5.1f} BPM | Phase: {sim.get_current_phase()['name']:16s} | Waiting for client...", end="", flush=True)
        await asyncio.sleep(0.5)


async def main(port: int):
    print(f"Life Magic HR Simulator")
    print(f"=======================")
    print(f"WebSocket server on ws://localhost:{port}")
    print(f"Workout loop: Rest -> Warmup -> Sets -> Cooldown -> (repeat)")
    print(f"Press Ctrl+C to stop.\n")

    async with websockets.serve(handler, "localhost", port):
        await broadcast_loop()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="HR Simulator for Life Magic")
    parser.add_argument("--port", type=int, default=PORT)
    args = parser.parse_args()

    try:
        asyncio.run(main(args.port))
    except KeyboardInterrupt:
        print("\n\nSimulator stopped.")
