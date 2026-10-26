# Nuclei Linux SDK 项目知识库

## 一、项目概述

### 1.1 项目简介
Nuclei Linux SDK 是为 Nuclei RISC-V Linux 处理器提供的完整软件开发套件，包含 OpenSBI、U-Boot、Linux Kernel 和 Buildroot 等组件。

### 1.2 支持的硬件平台
- **FPGA 评估板**: DDR200T、KU060、VCU118
- **SoC**: evalsoc（demosoc 已废弃）
- **CPU 核心**: UX600、UX900 系列（rv64imac/rv64imafdc）

### 1.3 组件版本（dev_nuclei_6.6_v2 分支）
| 组件 | 版本 | 说明 |
|------|------|------|
| Linux Kernel | 6.6.y | 主线内核 |
| U-Boot | v2023.10 | 引导加载程序 |
| OpenSBI | v1.3.1+ | RISC-V SBI 实现 |
| Buildroot | 2023.08.4 | 根文件系统构建 |
| GCC Toolchain | 13.1.1 | RISC-V 交叉编译器 |

### 1.4 当前分支限制
- ⚠️ 仅支持 `CORE=ux900fd rv64imafdc` 配置
- ⚠️ 仅支持 `BOOT_MODE=sd`（SD卡启动）
- ⚠️ 不支持 AMP（非对称多处理）

---

## 二、环境搭建

### 2.1 系统要求
- **主机**: Ubuntu 20.04 x86_64（推荐）
- **磁盘空间**: 约 2GB
- **网络**: 需要连接外网下载依赖包

### 2.2 安装依赖
```bash
# 安装系统依赖
sudo xargs apt-get install -y < .github/apt.txt

# 安装 Python 依赖
sudo pip3 install -r .github/pipreq.txt

# mtools 版本要求 >= 4.0.24
```

### 2.3 安装 Nuclei 工具链
从 [Nuclei Development Tools](https://nucleisys.com/download.php#tools) 下载：
- `openocd` (>= 2023.10)
- `qemu-system-riscv64` (>= 2023.10)

```bash
export PATH=/path/to/openocd/bin:/path/to/qemu/bin:$PATH
which openocd qemu-system-riscv64
```

### 2.4 已知问题修复
**libgmp.so.3 缺失问题：**
```bash
sudo ln -s /lib/x86_64-linux-gnu/libgmp.so /lib/x86_64-linux-gnu/libgmp.so.3
```

---

## 三、代码获取与配置

### 3.1 克隆仓库
```bash
# 主分支克隆
git clone -b dev_nuclei_6.6_v2 https://github.com/Nuclei-Software/nuclei-linux-sdk
cd nuclei-linux-sdk

# 初始化子模块（约 1.7GB）
git submodule update --recursive --init

# 或使用浅克隆加速
git submodule update --init --depth=1
```

**子模块列表：**
- `buildroot`: 根文件系统构建
- `freeloader`: 第一阶段引导加载程序
- `linux`: Linux 内核源码
- `opensbi`: RISC-V SBI 固件
- `u-boot`: U-Boot 引导加载程序

### 3.2 Makefile 关键配置
编辑 `Makefile` 选择正确的配置：

```makefile
# CPU 核心配置（必选其一）
CORE ?= ux900fd          # rv64imafdc，带 FPU（默认）
# CORE ?= ux600          # rv64imac，无 FPU
# CORE ?= u900           # rv32imac（32位）
# CORE ?= u900fd         # rv32imafdc（32位）

# SoC 配置
SOC ?= evalsoc           # 默认 evalsoc（demosoc 已废弃）

# 启动模式
BOOT_MODE ?= sd          # sd 或 flash
```

### 3.3 SoC 频率配置
在 `conf/$SOC/build.mk` 中配置频率：

```makefile
TIMER_HZ    ?= 32768      # 定时器频率
CPU_HZ      ?= 50000000   # CPU 频率（默认 50MHz）
PERIPH_HZ   ?= 50000000   # 外设频率
SIMULATION  ?= 0          # 仿真模式（仅保留 UART）
```

或在 DTS 文件中修改 `nuclei_rv64imafdc.dts` 中的 `CPUCLK_FREQ`。

---

## 四、编译构建

### 4.1 常用 Make 命令

```bash
# 显示帮助
make help

# 编译 freeloader（包含 OpenSBI + U-Boot + DTB）
make freeloader

# 编译所有启动镜像（kernel + rootfs）
make bootimages

# 编译全部
make all

# 清理构建
make clean
make distclean
```

### 4.2 编译输出目录结构
```
work/
└── evalsoc/
    ├── freeloader/
    │   └── freeloader.elf       # 第一阶段引导程序
    ├── opensbi/
    │   └── platform/generic/firmware/
    │       └── fw_payload.elf   # OpenSBI 固件
    ├── u-boot/
    │   └── u-boot               # U-Boot 二进制
    ├── linux/
    │   └── arch/riscv/boot/
    │       └── Image            # Linux 内核
    ├── buildroot/
    │   └── images/
    │       └── rootfs.cpio      # 根文件系统
    └── boot/                    # SD卡启动文件
        ├── boot.scr             # U-Boot 启动脚本
        ├── kernel.dtb           # 设备树（可选）
        ├── uImage.lz4           # 压缩内核
        └── uInitrd.lz4          # 压缩根文件系统
```

### 4.3 启动镜像文件说明
| 文件 | 必需 | 说明 |
|------|------|------|
| boot.scr | ✅ | U-Boot 启动脚本 |
| uImage.lz4 | ✅ | LZ4 压缩的内核镜像 |
| uInitrd.lz4 | ✅ | LZ4 压缩的根文件系统 |
| kernel.dtb | ❌ | 设备树二进制（freeloader 已包含） |

---

## 五、程序烧录

### 5.1 烧录方法概述
Freeloader 有三种烧录方式：

| 方法 | 是否需要编译 | 适用场景 |
|------|-------------|----------|
| 方法1: Linux SDK | ✅ 需要 | 开发者，有源码修改需求 |
| 方法2: Nuclei SDK | ❌ 不需要 | 快速测试，使用预编译 ELF |
| 方法3: Nuclei Studio | ❌ 不需要 | 图形界面，IDE 用户 |

### 5.2 方法1：使用 Linux SDK 烧录
```bash
# 编译并烧录（需要连接 JTAG）
make upload_freeloader
```

### 5.3 方法2：使用 Nuclei SDK 烧录

**步骤1：准备 Nuclei SDK**
```bash
# 参考 https://doc.nucleisys.com/nuclei_sdk/quickstart.html 安装 SDK
```

**步骤2：下载预编译 freeloader**
从 GitHub Actions 下载 `bootimages_ux600_sd` Artifacts，解压后得到 `freeloader/freeloader.elf`。

**步骤3：使用 GDB 加载**
```bash
# 在 nuclei-sdk 目录下执行
cd nuclei-sdk

# 启动 GDB 调试会话
make CORE=ux600 DOWNLOAD=flashxip BOARD=nuclei_fpga_eval SOC=demosoc debug

# 在 GDB 中加载 freeloader
(gdb) load /path/to/freeloader.elf
(gdb) monitor resume
(gdb) quit
```

### 5.4 方法3：使用 Nuclei Studio IDE 烧录

**步骤1：下载工具**
- Nuclei Studio: [下载页面](https://www.nucleisys.com/download.php)
- freeloader.elf: GitHub Actions Artifacts

**步骤2：创建工程**
1. `File -> New -> C/C++ Project`
2. 选择 `C Managed Build`
3. 项目名: 任意
4. 项目类型: `Nuclei SDK Project For Nuclei demosoc SoC`
5. 配置参数:
   - Board: `nuclei_fpga_eval`
   - Core: `Ux600 (ARCH=rv64imac,ABI=lp64)`
   - DOWNLOAD: `FLASHXIP`

**步骤3：配置 Run Configuration**
1. 右键项目 → `Run As -> Run Configurations`
2. 选择 `GDB OpenOCD Debugging -> Freeloader_debug_openocd`
3. 在 Main 选项卡中浏览选择 `freeloader.elf`
4. 点击 `Apply` 保存

**步骤4：烧录运行**
1. 连接开发板
2. 选择 `Freeloader_debug_openocd` 配置
3. 点击工具栏 Run 按钮（绿色播放图标）

---

## 六、调试指南

### 6.1 调试架构概述
```
┌─────────────────┐         ┌─────────────┐         ┌─────────────┐
│   NucleiStudio  │         │   OpenOCD   │         │  FPGA Board │
│   (GDB Client)  │◄──USB──►│  (GDB Svr)  │◄─JTAG──►│   (Target)  │
└─────────────────┘         └─────────────┘         └─────────────┘
```

### 6.2 新建 Debug Configuration

**1. 打开 Debug Configurations**
- 菜单: `Run -> Debug Configurations`
- 左侧: 双击 `GDB OpenOCD Debugging`
- 或右键创建 `New_configuration`

**2. 配置 Main 选项卡**
- C/C++ Application: 选择要调试的 ELF 文件
  - Linux Kernel: `work/evalsoc/linux/vmlinux`
  - U-Boot: `work/evalsoc/u-boot/u-boot`
  - OpenSBI: `work/evalsoc/opensbi/platform/generic/firmware/fw_payload.elf`

**3. 配置 Debugger 选项卡**
- OpenOCD 路径: IDE 自带或自定义路径
- Config options: `-f /path/to/openocd.cfg`
  - evalsoc: `nuclei-linux-sdk/conf/evalsoc/openocd.cfg`
- GDB port: 默认 3333

**4. 配置 Startup 选项卡**
- ☑️ Load Symbols（加载符号表）
- ☐ Load Executable（通常不加载，已经在板上运行）

**5. 配置 Source 选项卡（路径映射）**
添加 Path Mapping：
- 编译路径 → 源码路径
- 例: `/home/user/nuclei-linux-sdk` → `Y:\home\user\nuclei-linux-sdk`

### 6.3 调试技巧

**关键调试功能：**
- **按指令单步**: 点击 `i->` 图标启用 Instruction Step Mode
- **设置断点**: 在汇编指令前双击
- **查看内存**: `Window -> Show View -> Memory`
  - 支持物理地址和虚拟地址（需开启 MMU）
- **手动 GDB 命令**: 在 Debugger Console 中直接输入

**修改 PC 指针：**
当 CPU 停在死循环处（如 `asm volatile("j .")`），需要 PC+4：
1. 在下一行汇编代码上右键
2. 选择 `Move to Line`

---

## 七、常见问题与解决方案

### 7.1 构建相关问题

**Q: git submodule 更新失败**
```bash
# 使用浅克隆减少数据量
git submodule update --init --depth=1

# 或尝试多次重试
```

**Q: libgmp.so.3 缺失**
```bash
sudo ln -s /lib/x86_64-linux-gnu/libgmp.so /lib/x86_64-linux-gnu/libgmp.so.3
```

**Q: 网络问题导致 buildroot 包下载失败**
- 检查网络连接
- 配置代理
- 或手动下载包放到 `buildroot/dl/` 目录

### 7.2 调试相关问题

**Q: 断点异常提示（跨 Image 调试）**
**原因**: 跨镜像调试时，断点地址不在当前镜像内存范围内
**解决**: 跨镜像前删除所有断点

**Q: 调试时符号表对不上（U-Boot 重定位后）**
```gdb
# 在 Debugger Console 中获取重定位偏移
(gdb) p /x ((gd_t*)$gp)->reloc_off
$2 = 0x7dd8e000

# 使用 -o 参数重新加载符号表
(gdb) symbol-file u-boot -o 0x7dd8e000
```

**Q: 没有源码对应**
**可能原因**:
1. 编译时未加 `-g` 选项
2. 加载的 ELF 和源码不是同一工程

**解决**: 确保编译时使用 `-g -Og` 选项

**Q: 如何定位异常**
1. 查看当前特权模式：`info reg priv`
2. **Machine 模式**: 查看 `mepc mcause mtval`
3. **Supervisor 模式**: 查看 `sepc scause stval`
4. 查看异常入口: `mtvec` / `stvec`
5. Nuclei 特有: `mdcause` / `sdcause`

参考文档:
- [RISC-V Privileged Spec](https://github.com/riscv/riscv-isa-manual/releases)
- Nuclei_RISC-V_ISA_Spec.pdf

### 7.3 运行相关问题

**Q: 启动卡在 U-Boot**
- 检查 SD 卡格式（FAT32，单分区）
- 确认 boot.scr、uImage.lz4、uInitrd.lz4 在 SD 卡根目录
- 检查 UART 连接（115200bps，无流控）

**Q: 无法登录**
- 用户名: `root`
- 密码: `nuclei`

**Q: 免密码登录（开发调试用）**
在 buildroot 配置中修改，或修改 `/etc/inittab`。

---

## 八、UART 串口配置

### 8.1 连接参数
| 参数 | 值 |
|------|-----|
| 波特率 | 115200 bps |
| 数据位 | 8 bit |
| 校验位 | None |
| 停止位 | 1 bit |
| 流控 | **必须关闭** |

### 8.2 启动流程示例输出
```
OpenSBI v1.3
...
U-Boot 2023.10
...
Starting kernel ...
[    0.000000] Linux version 6.6.7+
...
Welcome to Nuclei System Technology
nucleisys login: root
Password: nuclei
```

---

## 九、参考资源

### 9.1 官方文档
- [Nuclei Linux SDK GitHub](https://github.com/Nuclei-Software/nuclei-linux-sdk)
- [Nuclei SDK 文档](https://doc.nucleisys.com/nuclei_sdk/)
- [Nuclei Studio IDE](https://doc.nucleisys.com/nuclei_tools/ide/)
- [Eclipse Embedded CDT](https://eclipse-embed-cdt.github.io/)

### 9.2 技术规范
- [RISC-V ISA Manual](https://riscv.org/technical/specifications/)
- [RISC-V Privileged Spec](https://github.com/riscv/riscv-isa-manual)

### 9.3 社区支持
- [GitHub Issues](https://github.com/Nuclei-Software/nuclei-linux-sdk/issues)
- 邮件: contact@nucleisys.com

---

## 十、开发工作流

### 10.1 标准开发流程
```bash
# 1. 克隆并初始化
git clone -b dev_nuclei_6.6_v2 https://github.com/Nuclei-Software/nuclei-linux-sdk
cd nuclei-linux-sdk
git submodule update --init --depth=1

# 2. 配置 Makefile（选择 CORE 和 SOC）
vim Makefile

# 3. 编译 freeloader
make freeloader

# 4. 烧录到开发板
make upload_freeloader

# 5. 制作启动镜像
make bootimages

# 6. 复制到 SD 卡
cp work/evalsoc/boot/* /media/sdcard/

# 7. 复位开发板，从 SD 卡启动
```

### 10.2 调试工作流
```bash
# 1. 添加死循环到内核代码（用于暂停）
asm volatile("j .");

# 2. 重新编译
make freeloader
make upload_freeloader

# 3. 在 NucleiStudio 中配置 Debug Configuration
# 4. 连接 JTAG，启动调试会话
# 5. PC+4 后单步调试
```

---

## 十一、项目文档索引

**所有项目文档统一存放于 [`doc/`](doc/README.md)，完整索引见 [`doc/README.md`](doc/README.md)。**
开始分析或开发任务前，先读该索引，确认是否已有相关设计文档或历史记录，避免重复分析。

| 主题 | 入口文档 | 内容 |
|------|---------|------|
| HSM / 安全启动 | [doc/hsm/Nuclei_HSM_Secure_Boot.md](doc/hsm/Nuclei_HSM_Secure_Boot.md) | 安全启动流程与实现说明 |
| HSM 配置改动 | [doc/hsm/conf修改分析.md](doc/hsm/conf修改分析.md) | `conf/evalsoc` 下全部修改分析（含变更总览图） |
| OP-TEE 总览 | [doc/optee/PROJECT_ANALYSIS.md](doc/optee/PROJECT_ANALYSIS.md) | 目录结构、组件关系、构建链路 |
| OP-TEE 密钥体系 | [doc/optee/OP-TEE密钥体系说明.md](doc/optee/OP-TEE密钥体系说明.md) | HUK / SSK / TA 密钥层级与派生 |
| OP-TEE 内置 TA | [doc/optee/OP-TEE可信应用开发包与内置TA说明.md](doc/optee/OP-TEE可信应用开发包与内置TA说明.md) | TA 开发包结构与 HUK 密封/解封 |
| OP-TEE 编译问题 | [doc/optee/OP-TEE编译问题修复报告.md](doc/optee/OP-TEE编译问题修复报告.md) | 编译报错根因与修复记录 |
| OP-TEE 修改总结 | [doc/optee/代码修改总结报告.md](doc/optee/代码修改总结报告.md) | 代码修改汇总与影响评估 |
| OP-TEE 提交分析 | [doc/optee/提交代码详细分析.md](doc/optee/提交代码详细分析.md) | 逐条提交分析与关联关系 |
| OpenSBI 入门 | [doc/opensbi/OpenSBI学习与开发文档.md](doc/opensbi/OpenSBI学习与开发文档.md) | 架构、启动流程与开发指引 |
| OpenSBI 改动 | [doc/opensbi/opensbi代码修改说明.md](doc/opensbi/opensbi代码修改说明.md) | 本 SDK 对 OpenSBI 的改动点 |
| U-Boot 修改 | [doc/uboot/uboot修改分析.md](doc/uboot/uboot修改分析.md) | U-Boot Nuclei HSM 分支 6 个提交的逐项分析 |
| 密码学接口 | [doc/crypto/nuclei_linux密码学接口.md](doc/crypto/nuclei_linux密码学接口.md) | HSM + Mailbox 加解密/哈希接口 |
| 构建流程 | [doc/build/make%20freeloader的构建顺序.md](doc/build/make%20freeloader的构建顺序.md) | freeloader 构建依赖与执行顺序 |
| Patch 对比 | [doc/patch/Patch文件对比分析报告.md](doc/patch/Patch文件对比分析报告.md) | 与上游逐文件对比分析 |

**文档维护约定：**
- 新增文档按主题放入 `doc/<主题>/`（`hsm` / `optee` / `opensbi` / `uboot` / `crypto` / `build` / `patch` / `misc`）
- 图片目录命名为 `{文档名}_images/`，与文档同目录，使用相对路径引用
- Graphviz 图表保留 `.dot` 源文件，导出 SVG
- 新增或重命名文档后同步更新 `doc/README.md` 与本索引

---

*文档版本: 基于 dev_nuclei_6.6_v2 分支*
*最后更新: 2024年*
