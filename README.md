# Asynchronous FIFO for Clock Domain Crossing (Verilog)

A parameterizable **dual-clock (asynchronous) FIFO** in Verilog that safely moves data between two unrelated clock domains. It uses **Gray-coded pointers** and **2-flop synchronizers** to avoid metastability and multi-bit synchronization errors, and generates `full` and `empty` flags in their own clock domains.

Simulated and verified in **Xilinx Vivado**.

---

## Features

- Independent write clock (`wclk`) and read clock (`rclk`)
- Parameterizable depth and data width (`DEPTH`, `DATA_WIDTH`)
- Binary and Gray pointers, with one extra MSB to tell full from empty
- 2-flop synchronizers for pointer transfer across domains
- `full` generated in the write domain, `empty` in the read domain
- Active-low asynchronous reset for each domain (`wrst_n`, `rrst_n`)
- Write and read operations are protected: no write when full, no read when empty

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DEPTH` | 8 | Number of entries (must be a power of 2) |
| `DATA_WIDTH` | 8 | Width of each entry in bits |
| `PTR_WIDTH` | `$clog2(DEPTH)` | Address width (pointers are `PTR_WIDTH+1` bits) |

---

## Architecture

<img width="2280" height="1335" alt="async_fifo_architecture" src="https://github.com/user-attachments/assets/33db1436-bea4-45eb-b697-99824a1e18dd" />


The design has four building blocks:

| Module | Clock domain | Role |
|--------|--------------|------|
| `wptr_handler` | `wclk` | Maintains the binary and Gray write pointer, generates `full` |
| `rptr_handler` | `rclk` | Maintains the binary and Gray read pointer, generates `empty` |
| `synchronizer` | Destination clock | 2-flop synchronizer for the Gray pointer crossing domains |
| `fifo_mem` | Write and read | Dual-port memory array: written on `wclk`, read on `rclk` |

### Module hierarchy

```
asynchronous_fifo            (top level)
├── wptr_handler             (write pointer + full flag)
├── rptr_handler             (read pointer + empty flag)
├── synchronizer  sync_wptr  (write pointer → read domain)
├── synchronizer  sync_rptr  (read pointer → write domain)
└── fifo_mem                 (storage)
```

---

## How It Works

**1. Why Gray code?**
A binary counter can change several bits at once (e.g. `0111 → 1000`). If another clock samples it mid-change, it can read a completely wrong value. A Gray-coded counter changes only **one bit per increment**, so the sampled value is always either the old or the new pointer, never garbage.

**2. Pointer crossing**
Each domain converts its binary pointer to Gray (`gray = (bin >> 1) ^ bin`) and sends it through a 2-flop synchronizer into the other domain, which reduces the chance of metastability.

**3. Empty condition (read domain)**
The FIFO is empty when the next read pointer equals the synchronized write pointer (both in Gray code):

```verilog
assign rempty = (g_wptr_sync == g_rptr_next);
```

**4. Full condition (write domain)**
The FIFO is full when the next write pointer equals the synchronized read pointer with its **two MSBs inverted** (the Gray-code equivalent of "wrapped around once"):

```verilog
assign wfull = (g_wptr_next == {~g_rptr_sync[PTR_WIDTH:PTR_WIDTH-1],
                                 g_rptr_sync[PTR_WIDTH-2:0]});
```

Because each pointer reaches the other domain a couple of cycles late, `full` and `empty` are slightly **conservative**: the FIFO may report full or empty a little early, but it never overflows or underflows.

---

## Port Description

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `wclk` | in | 1 | Write clock |
| `wrst_n` | in | 1 | Write-domain reset, active low |
| `w_en` | in | 1 | Write enable |
| `data_in` | in | `DATA_WIDTH` | Data to write |
| `full` | out | 1 | FIFO full (write domain) |
| `rclk` | in | 1 | Read clock |
| `rrst_n` | in | 1 | Read-domain reset, active low |
| `r_en` | in | 1 | Read enable |
| `data_out` | out | `DATA_WIDTH` | Read data (valid the cycle after `r_en`) |
| `empty` | out | 1 | FIFO empty (read domain) |

---

## Repository Structure

```
async-fifo-cdc-verilog/
├── rtl/
│   └── asynchronous_fifo.v     # all RTL modules
├── tb/
│   └── tb_async_fifo.v         # testbench
├── docs/
│   ├── async_fifo_architecture.png
│   ├── waveform.png
│   └── schematic.png
└── README.md
```

---

## Verification

`tb_async_fifo.v` is a self-checking testbench with two unrelated clocks:

| Clock | Period | Frequency |
|-------|--------|-----------|
| `wclk` | 10 ns | 100 MHz |
| `rclk` | 14 ns | about 71 MHz |

**Test sequence**
1. Apply reset to both domains
2. Write 8 values into the FIFO (`0xA0` to `0xA7`)
3. Read all 8 values back, waiting while `empty` is high
4. Compare each read value with the expected value and print `PASS` or `FAIL`

**Expected console output**
```
Read[0] = a0, Expected = a0 PASS
Read[1] = a1, Expected = a1 PASS
Read[2] = a2, Expected = a2 PASS
Read[3] = a3, Expected = a3 PASS
Read[4] = a4, Expected = a4 PASS
Read[5] = a5, Expected = a5 PASS
Read[6] = a6, Expected = a6 PASS
```

### Simulation waveform
<img width="1902" height="1015" alt="Screenshot 2026-10-23 012927" src="https://github.com/user-attachments/assets/1f9dc7f9-7f7f-47f4-99e8-e754b9a218ca" />


### RTL schematic (Vivado)
<img width="1556" height="636" alt="Screenshot 2026-02-05 125719" src="https://github.com/user-attachments/assets/4ac48385-f271-4449-a0e4-1cc8815951b7" />


---

## How to Run (Vivado)

1. Create a new RTL project in Vivado
2. Add `rtl/asynchronous_fifo.v` as a **design source**
3. Add `tb/tb_async_fifo.v` as a **simulation source** and set `tb_async_fifo` as the simulation top
4. Click **Run Simulation → Run Behavioral Simulation**
5. Run for about 500 ns and check the Tcl console for the `PASS` messages

---

## Tools Used

- Verilog HDL
- Xilinx Vivado (behavioral simulation, elaborated schematic)

---

## Limitations and Future Work

- Testbench is directed: it writes then reads. It does not yet test the `full` flag, simultaneous read and write, or pointer wrap-around.
- `DEPTH` must be a power of 2.
- Reset de-assertion is not synchronized to each clock; adding reset synchronizers would make it more robust.
- Possible extensions: almost-full / almost-empty flags, randomized testbench with a scoreboard, SystemVerilog assertions, FPGA synthesis with timing and utilization report.

---



## References

- Clifford E. Cummings, *Simulation and Synthesis Techniques for Asynchronous FIFO Design*, SNUG 2002
