#!/usr/bin/env bash
# 照上游 verilator/run_verilator.sh 用 bender 出文件表，另做两件事：
# croc_pkg.sv 的两个 localparam 改成读宏（-D 碰不到 localparam），默认值照抄上游；
# 路径改成相对包根。rtl.f 是黑盒本身，sim.f 多出上游的测试台。
set -euo pipefail
cd "$(dirname "$0")/.."
U=third_party/croc
O=build/flist
command -v bender >/dev/null || { echo "要 bender：github.com/pulp-platform/bender/releases"; exit 1; }
rm -rf "$O"
mkdir -p "$O"
pkg=$O/croc_pkg.sv
cp "$U/rtl/croc_pkg.sv" "$pkg"
hook() {
  local re="(localparam[[:space:]]+[a-z]+[[:space:]]+$1[[:space:]]*=)[[:space:]]*([^;]+);"
  local was
  was=$(sed -n -E "s/.*$re.*/\2/p" "$pkg")
  [ -n "$was" ] || { echo "croc_pkg.sv 里没有 localparam $1，上游改了写法"; exit 1; }
  sed -i -E "s/$re/\1 \`$2;/" "$pkg"
  sed -i "1i \`ifndef $2\n\`define $2 $was\n\`endif" "$pkg"
}
hook iDMAEnable CROC_IDMA_ENABLE
hook CorePMPEnable CROC_PMP_ENABLE
flist() {
  (cd "$U" && bender script flist-plus "$@" -D VERILATOR=1 -D COMMON_CELLS_ASSERTS_OFF=1) |
    sed -e "s|$PWD/||g" -e "s|^$U/rtl/croc_pkg.sv\$|$pkg|"
}
flist -t rtl -t synthesis > "$O/rtl.f"
flist -t rtl -t verilator -t synthesis > "$O/sim.f"
grep -qx "$pkg" "$O/rtl.f" || { echo "文件表里没替换到 croc_pkg.sv"; exit 1; }
