# UART Controller — RTL Implementation in Verilog

A fully parameterized UART transceiver implemented in synthesizable Verilog,
featuring a 16x oversampled receiver with false-start rejection and a
baud-rate-accurate transmitter. Built as a portfolio project targeting VLSI/embedded roles at companies like TI, Qualcomm, and Marvell.

**Clock:** 50 MHz | **Baud Rate:** 9600 (configurable) | **Data Format:** 8N1

---

## Features

- Parameterized baud rate — single `CLK_FREQ` and `BAUD_RATE` parameter drives all timing, no magic numbers
- 16x oversampling RX with center-of-bit sampling (tick 7) and false-start rejection
- Zero-drift dual-counter baud generator — no accumulation error over long transmissions
- All FSM transitions gated by `baud_tick` to prevent bit-period clipping
- Top-level `uart_top.v` integrating TX, RX, and baud generator
- GTKWave-verified waveforms for all modules

---

## Block Diagram

![Block Diagram](docs/block_diagram.png)

---

## Architecture & Design Decisions

### Baud Rate Generator (`baud_gen.v`)
Dual-counter architecture. A primary counter divides the 50 MHz clock to produce `baud_tick_16x` at 16× the baud rate (every 325 cycles at 9600 baud). A secondary 0–15 counter derives `baud_tick` from it. This eliminates the drift that a single large independent counter would accumulate over multiple frames.

### TX FSM (`uart_tx.v`)
Two-process Moore FSM with 5 states: `IDLE → START → DATA → PARITY → STOP`. All state transitions are gated by `baud_tick` to ensure each bit holds for exactly one baud period. The `tx_busy` signal is asserted for the full frame duration, preventing new data from being loaded mid-transmission.

### RX FSM (`uart_rx.v`)
16x oversampling with false-start rejection. On detecting a falling edge on `rx_in`, the FSM counts 7 `baud_tick_16x` pulses to reach the center of the start bit and samples it. If `rx_in` is still low, the start bit is valid and reception proceeds. If `rx_in` is high, the FSM returns to `IDLE` — this filters out noise glitches that would otherwise cause corrupt frames. Each subsequent data bit is sampled at its own center using the same 16-tick counting mechanism.

---

## FSM Diagrams

| TX FSM | RX FSM |
|--------|--------|
| ![TX FSM](docs/transmitter_tx.png) | ![RX FSM](docs/receiver_rx.png) |

---

## Repository Structure
uart-verilog/

├── rtl/

│   ├── baud_gen.v

│   ├── uart_tx.v

│   ├── uart_rx.v

│   └── uart_top.v

├── tb/

│   ├── baud_gen_tb.v

│   ├── uart_tx_tb.v

│   └── uart_rx_tb.v

├── sim/

│   ├── uart_tx.vcd

│   └── uart_rx.vcd

├── docs/

│   ├── block_diagram.png

│   ├── tx_fsm.png

│   └── rx_fsm.png

└── README.md
---

## Parameters

| Parameter  | Default    | Description                        |
|------------|------------|------------------------------------|
| CLK_FREQ   | 50_000_000 | System clock frequency in Hz       |
| BAUD_RATE  | 9600       | UART baud rate                     |
| DATA_BITS  | 8          | Number of data bits per frame      |

---

## Simulation — How to Run

```bash
# Clone the repository
git clone https://github.com/Vatsal1745/uart-verilog.git
cd uart-verilog

# Simulate TX
iverilog -o sim/uart_tx_sim rtl/baud_gen.v rtl/uart_tx.v tb/uart_tx_tb.v
vvp sim/uart_tx_sim

# Simulate RX
iverilog -o sim/uart_rx_sim rtl/baud_gen.v rtl/uart_rx.v tb/uart_rx_tb.v
vvp sim/uart_rx_sim

# View waveforms
gtkwave sim/uart_tx.vcd
gtkwave sim/uart_rx.vcd
```

---

## Verified Waveforms

### TX Output — 0x55 Test Pattern
![TX Waveform](docs/tx_waveform.png)

### RX Output — Loopback Verification
![RX Waveform](docs/rx_waveform.png)

---

## Key Signals

| Signal         | Direction | Description                            |
|----------------|-----------|----------------------------------------|
| `clk`          | Input     | System clock (50 MHz)                  |
| `rst`          | Input     | Active-high synchronous reset          |
| `tx_start`     | Input     | Pulse to begin transmission            |
| `data_in[7:0]` | Input     | Parallel data to transmit              |
| `tx_out`       | Output    | Serial TX line                         |
| `tx_busy`      | Output    | High during active transmission        |
| `rx_in`        | Input     | Serial RX line                         |
| `data_out[7:0]`| Output    | Received parallel data                 |
| `rx_done`      | Output    | Pulses high when a frame is received   |

---

## Learning Outcomes

- Understood the relationship between oversampling ratio and clock tolerance in asynchronous serial receivers
- Implemented false-start rejection — a design quality requirement in real UART hardware, not just a textbook concept
- Debugged bit-period clipping by tracing FSM transition timing in GTKWave
- Built a parameterized architecture that can retarget to any baud rate or clock frequency by changing two parameters

---

## Tools Used

- **Simulation:** Icarus Verilog (`iverilog` / `vvp`)
- **Waveform Viewer:** GTKWave
- **Language:** Verilog HDL (synthesizable RTL)
- **Version Control:** Git / GitHub