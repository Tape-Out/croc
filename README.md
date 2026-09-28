# croc

PULP's [Croc](https://github.com/pulp-platform/croc), a small SoC around the CVE2 core with OBI inside, taped out in IHP 130 nm, taken as a black box.

![maturity](https://img.shields.io/badge/maturity-planned-lightgrey) ![license](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0%20OR%20MulanPSL--2.0-blue) ![upstream](https://img.shields.io/badge/upstream-SHL--0.51-lightgrey)

Part of the [Tape-Out](https://github.com/Tape-Out) IP library, wired up by [`xirang`](https://github.com/Tape-Out/xirang). One submodule, not modified: `third_party/croc`. Its own submodules (the two IHP PDKs and `artistic`) are not fetched.

## What this repository adds

Upstream vendors every dependency into `rtl/` and lists the sources with [bender](https://github.com/pulp-platform/bender). The `flist` setup task runs bender with the targets upstream's `verilator/run_verilator.sh` uses and writes two file lists under `build/flist/`: `rtl.f` for the SoC and `sim.f` with upstream's testbench added.

The configuration lives in `croc_pkg.sv` as localparams, out of `-D`'s and `-G`'s reach. The setup task copies that file and makes `iDMAEnable` and `CorePMPEnable` read a macro whose default is upstream's value; the `idma` and `pmp` knobs set the macros. The receipt reads both localparams back after elaboration at every point.

The top is `croc_soc`: the core, SRAM, peripherals and the debug module, without the pads of `croc_chip`. Its ports are JTAG, UART, GPIO, a second clock for the CLINT, the test mode input and a status output.

```console
$ ran run croc flist
$ ran test croc
```

## Testing

The `sim` task follows upstream's `.github/scripts/run_sim_flow.sh` at every point: it builds the software in `sw/` with `riscv64-unknown-elf-gcc` and upstream's testbench with Verilator, then runs

- `helloworld`, checking the UART greeting;
- `print_config`, which prints the SoC's hardware info register. The expected lines are computed from the point's knobs, so a knob that does not reach the RTL fails here;
- every unit test in `sw/test/`, each of which must end with `Simulation finished: SUCCESS`. `test_idma` runs only where the iDMA is on.

## Limits

The SRAM stays at two banks of 512 words, as the address map in `croc_pkg.sv` is written for that; changing the banks or their depth means changing the map too. The SRAM is the behavioural model from `tech_cells_generic`, not upstream's IHP macros. The user domain is empty, and its OBI ports are inside `croc_soc`. The CLINT's reference clock is listed with the other pins, as a package declares one clock for now.

## License

This repository: 任选其一 [MIT](LICENSE-MIT) · [Apache 2.0](LICENSE-APACHE) · [木兰宽松许可证 第2版](LICENSE-MULAN).

`third_party/croc` stays under **SHL-0.51** (Solderpad Hardware License), which lets a licensee take it under Apache-2.0 instead; see its `LICENSE.md`.
