#!/usr/bin/env bash
# 照上游 .github/scripts/run_sim_flow.sh：编 sw，用 Verilator 编测试台，跑 helloworld、print_config 与单元测试。
# print_config 打印的是硬件信息寄存器，期望值按这一点的旋钮算：旋钮没投影进 RTL，这一步就红。
# 用法：sim.sh <输出目录> <idma：True/False> <pmp：True/False> <gpioCount> [-D…]
set -euo pipefail
cd "$(dirname "$0")/.."
U=$PWD/third_party/croc
O=$(realpath -m "$1")
idma=$([ "$2" = True ] && echo 1 || echo 0)
pmp=$([ "$3" = True ] && echo 1 || echo 0)
gpio=$4
shift 4
X=${CROSS:-riscv64-unknown-elf-}
rm -rf "$O"
mkdir -p "$O"
say() { echo "$*"; exit 1; }

# 上游的链接带 -lm：它的工具链镜像有 C 库，Ubuntu 的裸机 GCC 没有，而程序本来就不调 libm。
# --no-relax：crt0.S 的 `la sp` 不在 norelax 里，binutils 2.42 会把它松弛成 gp 相对，而 gp 这时还没设
make -s -C "$U/sw" RISCV_PREFIX="$X" BINDIR="$O/bin" BUILDDIR="$O/sw" \
  RISCV_LDFLAGS='-static -nostartfiles -Wl,--no-relax -lgcc $(RISCV_FLAGS)' > "$O/sw.log" 2>&1 ||
  say "sw 编不过：$(grep -m1 -iE 'error' "$O/sw.log")"

verilator -Wno-fatal -Wno-style -Wno-BLKANDNBLK -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-WIDTHCONCAT \
  -Wno-ASCRANGE --binary -j "$(nproc)" --timing --autoflush --unroll-count 1 --unroll-stmts 1 \
  --x-assign fast --x-initial fast -O3 --top tb_croc_soc --Mdir "$O/obj" \
  -f build/flist/sim.f -GGpioCount="$gpio" "$@" > "$O/build.log" 2>&1 ||
  say "测试台编不过：$(grep -m1 '%Error' "$O/build.log")"

cd "$O"
mkdir -p test
run() { timeout "${2:-120}" obj/Vtb_croc_soc "+binary=bin/$1.hex" > "$1.log" 2>&1 || true; }
ok() { grep -q '\[JTAG\] Simulation finished: SUCCESS' "$1.log"; }

run helloworld
grep -q '\[UART\] Hello World from Croc!' helloworld.log || say "helloworld 没打出问候"

run test/print_config
has() { [ "$1" = 1 ] && echo present || echo 'not present'; }
want=(
  '\[UART\] Hello World from Croc v2!'
  "\[UART\]   iDMAEnable: $idma"
  '\[UART\]   Core: CVE2, RV32CIU'
  "\[UART\]   PMPEnable: $pmp"
  '\[UART\]   SRAM: 2h banks x 200h words'
  "\[UART\]   iDMA\s*: $(has $idma)"
  '\[UART\]   UART\s*: present'
  '\[UART\]   GPIO\s*: present'
)
for w in "${want[@]}"; do
  grep -q "$w" test/print_config.log || say "print_config 缺一行：$w"
done
ok test/print_config || say "print_config 没有以 SUCCESS 结束"

n=0
bad=()
for h in bin/test/test_*.hex; do
  t=test/$(basename "$h" .hex)
  # 没有 iDMA 的这一点上它无处可测
  [ "$t" = test/test_idma ] && [ "$idma" = 0 ] && continue
  run "$t"
  n=$((n + 1))
  ok "$t" || bad+=("${t#test/}")
done
echo "helloworld、print_config 与 $n 个单元测试；不过的：${bad[*]:-无}"
[ "$n" -gt 0 ] && [ ${#bad[@]} = 0 ]
