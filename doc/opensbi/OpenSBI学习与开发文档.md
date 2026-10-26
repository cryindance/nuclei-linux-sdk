# OpenSBI 学习与开发文档

## 📖 文档概述

本文档整理了 RISC-V OpenSBI（Open Source Supervisor Binary Interface）的完整学习资源，包括官方规范、本地代码库结构、技术细节和学习路径。

---

## 一、OpenSBI 简介

### 1.1 什么是 OpenSBI

**RISC-V Supervisor Binary Interface (SBI)** 是 RISC-V 架构中 S-mode（监管者模式）软件与 M-mode（机器模式）固件/硬件之间的标准接口。

**OpenSBI** 是 RISC-V SBI 规范的开源参考实现，主要功能：
- 提供平台无关的静态库 `libsbi.a`
- 实现 SBI 规范定义的所有标准扩展
- 为各平台提供参考固件实现
- 支持系统级分区（Domain）

### 1.2 架构定位

```
┌─────────────────────────────────────┐
│     S-Mode 软件 (Linux/U-Boot)      │
├─────────────────────────────────────┤
│           OpenSBI 接口层             │  ← SBI 调用 (ecall)
├─────────────────────────────────────┤
│     OpenSBI 实现 (M-Mode 固件)       │  ← libsbi.a / libplatsbi.a
├─────────────────────────────────────┤
│        平台特定硬件抽象层            │  ← platform.c
├─────────────────────────────────────┤
│         RISC-V 硬件平台              │
└─────────────────────────────────────┘
```

### 1.3 SBI 规范版本

| 版本 | 发布日期 | 状态 | 主要特性 |
|------|----------|------|----------|
| v0.1 | - | 已废弃 | 初始版本 |
| v0.2 | - | 经典版 | Legacy 扩展 |
| v1.0 | 2022-03-22 | ✅ Ratified | 标准扩展引入 |
| v2.0 | - | Frozen | 运行时 PMU、嵌套中断 |
| **v3.0** | **2025-07-16** | **✅ Ratified** | **最新官方版本** |

---

## 二、官方资源链接

### 2.1 核心仓库

| 资源名称 | URL | 说明 | 重要程度 |
|----------|-----|------|----------|
| **OpenSBI 主仓库** | https://github.com/riscv-software-src/opensbi | 官方源码，1417 ⭐ | ⭐⭐⭐⭐⭐ |
| **SBI 规范仓库** | https://github.com/riscv-non-isa/riscv-sbi-doc | 规范文档，464 ⭐ | ⭐⭐⭐⭐⭐ |
| **OpenSBI Google 镜像** | https://qemu.googlesource.com/opensbi | Google 镜像 | ⭐⭐⭐⭐ |

### 2.2 规范文档下载

| 版本 | 下载链接 | 状态 |
|------|----------|------|
| **SBI v3.0 (PDF)** | [官方 PDF](https://docs.riscv.org/reference/platform-software/sbi/_attachments/riscv-sbi.pdf) | ✅ 已批准 |
| SBI v1.0 (PDF) | [Stanford 镜像](https://www.scs.stanford.edu/~zyedidia/docs/riscv/riscv-sbi.pdf) | ✅ 已批准 |
| SBI v0.3 (RC) | [GitHub Release](https://github.com/riscv-non-isa/riscv-sbi-doc/releases/tag/v0.3.0-rc1) | 发布候选 |

### 2.3 RISC-V 官方资源

- **RISC-V SBI Wiki**: https://riscv.atlassian.net/wiki/spaces/HOME/pages/810057837/
- **RISC-V 文档中心**: https://doc-en.riscv.org/
- **OpenSBI 深度解析 PDF**: https://riscv.org/wp-content/uploads/2024/12/13.30-RISCV_OpenSBI_Deep_Dive_v5.pdf

### 2.4 社区教程

| 教程名称 | URL | 说明 |
|----------|-----|------|
| Hello OpenSBI | https://kanakshilledar.github.io/2024-09-08/hello-opensbi | Hello World 实战 |
| RISC-V SBI 启动流程 | https://popovicu.com/posts/risc-v-sbi-and-full-boot-process/ | 完整启动流程 |
| OpenSBI 在 Spike/QEMU | http://blogshakti.org.in/opensbi-on-spike-qemu-shakti/ | 多平台构建指南 |

---

## 三、本地代码库文档地图

### 3.1 代码库统计

- 📁 **源代码文件**: 263 个（.c/.h/.S/.ldS）
- 📄 **Markdown 文档**: 24 个
- 🏗️ **支持平台**: 11 个
- 🔌 **串口驱动**: 20+ 种
- 📦 **固件类型**: 3 种
- 🔧 **SBI 扩展**: 10+ 个

### 3.2 目录结构

```
opensbi/
├── 📄 README.md                    # 项目总览和编译指南
├── 📚 docs/                        # 文档目录（24个文件）
├── 🔧 firmware/                    # 固件示例和启动代码
├── 🏗️ platform/                    # 平台支持代码（11个平台）
├── 📖 include/sbi/                 # 头文件 API 定义
├── 💻 lib/sbi/                     # 核心库实现（50+文件）
├── 🔩 lib/utils/                   # 工具库和驱动程序
├── ⚙️ scripts/                     # 构建脚本
├── 📋 Makefile                     # 主构建文件
└── 🔧 Kconfig                      # 配置系统
```

### 3.3 核心文档详解

#### 3.3.1 项目文档

| 文档路径 | 说明 | 重要程度 |
|----------|------|----------|
| `README.md` | 项目概述、编译指南、快速入门 | ⭐⭐⭐⭐⭐ |
| `docs/contributing.md` | 代码贡献规范和提交规则 | ⭐⭐⭐⭐ |
| `CONTRIBUTORS.md` | 项目贡献者列表 | ⭐⭐⭐ |
| `COPYING.BSD` | BSD-2-Clause 许可证 | ⭐⭐⭐ |

#### 3.3.2 固件文档 (`docs/firmware/`)

| 文档 | 说明 | 内容概要 |
|------|------|----------|
| `fw.md` | 固件类型总览 | 三种固件类型的对比和选择指南 |
| `fw_dynamic.md` | 动态信息固件 | 运行时获取下一阶段信息的实现 |
| `fw_jump.md` | 跳转地址固件 | 固定跳转地址的配置和使用 |
| `fw_payload.md` | 载荷固件 | 直接嵌入下一阶段的实现 |
| `payload_linux.md` | Linux 载荷 | 将 Linux 内核作为 payload |
| `payload_uboot.md` | U-Boot 载荷 | 将 U-Boot 作为 payload |

#### 3.3.3 平台文档 (`docs/platform/`)

| 文档 | 平台 | 说明 |
|------|------|------|
| `platform.md` | - | 支持平台总览 |
| `generic.md` | Generic | FDT-based 通用平台 |
| `qemu_virt.md` | QEMU | QEMU Virt 机器支持 |
| `nuclei_ux600.md` | Nuclei | **Nuclei UX600 平台** |
| `sifive_fu540.md` | SiFive | SiFive FU540/FU740 |
| `spike.md` | Spike | RISC-V 官方模拟器 |
| `andes-ae350.md` | Andes | Andes AE350 平台 |
| `thead-c9xx.md` | T-Head | 平头哥 C9xx 系列 |

#### 3.3.4 开发指南

| 文档 | 说明 | 内容概要 |
|------|------|----------|
| `library_usage.md` | 库使用指南 | `libsbi.a` 的 API 和使用方法 |
| `platform_guide.md` | 平台移植指南 | 如何为新平台添加支持 |
| `platform_requirements.md` | 平台要求 | 硬件要求和 ISA 支持 |
| `domain_support.md` | 域支持详解 | 系统级分区（331行详尽文档） |
| `pmu_support.md` | PMU 支持 | 性能监控单元配置 |

### 3.4 源代码结构

#### 3.4.1 固件代码 (`firmware/`)

| 文件 | 说明 | 大小 |
|------|------|------|
| `fw_base.S` | 固件启动汇编（核心启动逻辑） | 20KB+ |
| `fw_base.ldS` | 固件链接脚本模板 | - |
| `fw_dynamic.S` | 动态固件实现 | - |
| `fw_jump.S` | 跳转固件实现 | - |
| `fw_payload.S` | 载荷固件实现 | - |
| `payloads/test_main.c` | 测试载荷示例 | - |

#### 3.4.2 核心库 (`lib/sbi/`)

| 文件 | 功能 | 大小 |
|------|------|------|
| `sbi_init.c` | 系统初始化 | 640 行 |
| `sbi_hart.c` | Hart 特性管理 | 22KB+ |
| `sbi_hsm.c` | Hart 状态管理（HSM扩展） | 14KB+ |
| `sbi_domain.c` | 域管理 | 20KB+ |
| `sbi_pmu.c` | PMU 实现 | 27KB+ |
| `sbi_trap.c` | 异常/陷阱处理 | 10KB+ |
| `sbi_ecall_*.c` | 各 SBI 扩展实现 | 多个文件 |

#### 3.4.3 头文件 API (`include/sbi/`)

| 文件 | 功能 | 行数 |
|------|------|------|
| `sbi_platform.h` | 平台操作接口定义 | 696 行 |
| `sbi_ecall_interface.h` | SBI 调用接口规范 | - |
| `sbi_types.h` | 基础类型定义 | - |
| `fw_dynamic.h` | 动态固件信息结构 | - |

#### 3.4.4 平台支持 (`platform/`)

| 目录 | 平台 | 说明 |
|------|------|------|
| `template/` | 模板 | 新平台移植参考模板（157行注释） |
| `nuclei/ux600/` | **Nuclei UX600** | **Nuclei 平台支持** |
| `generic/` | Generic | 通用 FDT 平台 |
| `sifive/` | SiFive | SiFive 系列平台 |
| `andes/` | Andes | Andes 平台 |

#### 3.4.5 驱动程序 (`lib/utils/`)

| 目录 | 驱动类型 | 数量 |
|------|----------|------|
| `serial/` | 串口驱动（UART） | 20+ 种 |
| `irqchip/` | 中断控制器 | PLIC/APLIC/IMSIC |
| `timer/` | 定时器 | ACLINT/Andes PLMT |
| `ipi/` | IPI 驱动 | ACLINT MSWI/Andes PLICSW |
| `fdt/` | 设备树解析 | libfdt 封装 |

---

## 四、固件类型详解

### 4.1 三种固件类型对比

| 特性 | FW_DYNAMIC | FW_JUMP | FW_PAYLOAD |
|------|------------|---------|------------|
| **下一阶段的获取方式** | 运行时动态获取 | 编译时固定地址 | 直接链接到固件中 |
| **适用场景** | 前级可加载多段镜像 | 固定跳转但前级无法加载 | 前级引导程序能力受限 |
| **灵活性** | 高 | 中 | 低 |
| **使用难度** | 中 | 低 | 低 |

### 4.2 FW_DYNAMIC（动态信息固件）

**工作原理**：通过 `struct fw_dynamic_info` 结构体运行时获取下一阶段信息

```c
struct fw_dynamic_info {
    unsigned long magic;        // 0x4942534F ("OBSI")
    unsigned long version;      // 版本号
    unsigned long next_addr;    // 下一阶段入口地址
    unsigned long next_arg1;    // 下一阶段参数 a1
    unsigned long next_mode;    // 下一阶段特权模式
    unsigned long options;      // OpenSBI 选项
};
```

**寄存器传递**：
- `a0`: hartid
- `a1`: FDT 地址
- `a2`: `struct fw_dynamic_info*` 地址

**编译命令**：
```bash
make PLATFORM=<platform> FW_DYNAMIC=y
```

### 4.3 FW_JUMP（跳转地址固件）

**工作原理**：编译时固定跳转地址，不包含下一阶段二进制

**配置参数**：
| 参数 | 说明 |
|------|------|
| `FW_JUMP_ADDR` | 下一阶段入口地址（绝对地址） |
| `FW_JUMP_OFFSET` | 相对 OpenSBI 加载地址的偏移 |
| `FW_JUMP_FDT_ADDR` | 传递给下一阶段的 FDT 地址 |

**编译命令**：
```bash
make PLATFORM=generic FW_JUMP=y FW_JUMP_ADDR=0x80200000
```

### 4.4 FW_PAYLOAD（载荷固件）

**工作原理**：将下一阶段二进制直接链接到固件镜像中

**配置参数**：
| 参数 | 说明 |
|------|------|
| `FW_PAYLOAD_PATH` | 下一阶段二进制文件路径 |
| `FW_PAYLOAD_OFFSET` | 载荷相对链接地址的偏移 |
| `FW_PAYLOAD_ALIGN` | 载荷对齐约束 |

**编译命令**：
```bash
make PLATFORM=generic FW_PAYLOAD=y FW_PAYLOAD_PATH=./u-boot.bin
```

---

## 五、SBI 扩展技术细节

### 5.1 标准扩展列表

| Extension ID | 名称 | 描述 | 状态 |
|--------------|------|------|------|
| 0x00 | Legacy | 遗留扩展（timer, ipi 等） | 兼容 |
| 0x01 | SRET | 返回 S-mode | 标准 |
| 0x02 | Set Timer | 设置定时器 | 标准 |
| 0x03 | IPI | 处理器间中断 | 标准 |
| 0x04 | RFNC | 远程 FENCE | 标准 |
| **0x05** | **HSM** | **Hart 状态管理** | **重要** |
| 0x06 | System Reset | 系统重置 | 标准 |
| 0x07 | System Suspend | 系统挂起 | 标准 |
| **0x08** | **PMU** | **性能监控单元** | **重要** |
| 0x09 | Nested Interrupt | 嵌套中断 | v2.0+ |
| 0x10 | Debug | 调试扩展 | 标准 |

### 5.2 HSM（Hart State Management）

**功能**：管理 Hart 的生命周期状态

**核心函数**：
```c
// 启动指定 hart
int sbi_hart_start(u32 hartid, ulong start_addr, ulong priv);

// 停止当前 hart
int sbi_hart_stop(void);

// 挂起 hart 到指定状态
int sbi_hart_suspend(u32 suspend_type, ulong resume_addr);

// 获取 hart 状态
int sbi_hart_get_status(u32 hartid);
```

**Hart 状态枚举**：
```c
enum sbi_hart_states {
    SBI_HART_STATE_STARTED = 0,   // 已启动
    SBI_HART_STATE_STOPPED = 1,   // 已停止
    SBI_HART_STATE_STARTING = 2,  // 启动中
    SBI_HART_STATE_STOPPING = 3,  // 停止中
    SBI_HART_STATE_SUSPENDED = 4, // 已挂起
};
```

### 5.3 PMU（Performance Monitoring Unit）

**功能**：性能监控和计数器管理

**硬件计数器类型**：
```c
enum pmu_hw_counter {
    SBI_PMU_HW_CPU_CYCLES = 0,        // CPU 周期
    SBI_PMU_HW_INSTRUCTIONS = 1,      // 指令数
    SBI_PMU_HW_CACHE_MISSES = 2,      // 缓存未命中
    SBI_PMU_HW_BRANCH_MISSES = 3,     // 分支预测失败
    SBI_PMU_HW_BUS_CYCLES = 4,        // 总线周期
    SBI_PMU_HW_STALLED_CYCLES = 5,    // 停顿周期
};
```

### 5.4 IPI（Inter-Processor Interrupt）

**功能**：处理器间中断

**IPI 类型**：
```c
enum sbi_ipi_type {
    SBI_IPI_SOFT = 0,         // 软件中断
    SBI_IPI_FENCE_I = 1,      // FENCE.I 同步
    SBI_IPI_SFENCE_VMA = 2,   // SFENCE.VMA 同步
    SBI_IPI_HFENCE_GVMA = 3,  // HFENCE.GVMA 同步（虚拟化）
    SBI_IPI_HFENCE_VVMA = 4,  // HFENCE.VVMA 同步（虚拟化）
};
```

### 5.5 RFENCE（Remote FENCE）

**功能**：远程内存屏障操作

**操作类型**：
```c
enum sbi_rfence_func {
    SBI_RFENCE_FENCE_I = 0,           // FENCE.I
    SBI_RFENCE_SFENCE_VMA = 1,        // SFENCE.VMA
    SBI_RFENCE_SFENCE_VMA_ASID = 2,   // SFENCE.VMA with ASID
    SBI_RFENCE_HFENCE_GVMA = 3,       // HFENCE.GVMA（虚拟化）
    SBI_RFENCE_HFENCE_GVMA_VMID = 4,  // HFENCE.GVMA with VMID
    SBI_RFENCE_HFENCE_VVMA = 5,       // HFENCE.VVMA（虚拟化）
    SBI_RFENCE_HFENCE_VVMA_ASID = 6,  // HFENCE.VVMA with ASID
};
```

---

## 六、平台移植指南

### 6.1 平台支持架构

```
libsbi.a（通用库）
    ↓
libplatsbi.a（平台库） ← platform.c（平台特定实现）
    ↓
固件镜像
```

### 6.2 核心数据结构

**平台定义结构** (`struct sbi_platform`)：
```c
struct sbi_platform {
    const char *name;
    
    // 硬件初始化
    int (*early_init)(void);
    int (*final_init)(void);
    
    // IPI 相关
    void (*ipi_init)(void);
    void (*ipi_clear)(u32 hartid);
    void (*ipi_send)(u32 target_hart);
    
    // Timer 相关
    void (*timer_init)(void);
    void (*timer_exit)(void);
    u64 (*timer_value)(void);
    
    // 系统相关
    void (*system_reset)(u32 reset_type, u32 reason);
    
    // Hart 映射
    int (*hart_index_to_hartid)(long idx);
    int (*hartid_to_hart_index)(u32 hartid);
};
```

### 6.3 新平台添加步骤

**步骤 1**: 创建平台目录
```bash
mkdir -p platform/<platform_name>
```

**步骤 2**: 创建配置文件
- `Kconfig` - 配置选项
- `configs/defconfig` - 默认配置

**步骤 3**: 创建 `objects.mk`
```makefile
platform_objs-y += platform.o
platform_objs-y += devices.o
platform_cflags-y += -O2
```

**步骤 4**: 创建 `platform.c`
```c
#include <sbi/sbi_platform.h>

static int myplatform_early_init(void) {
    // 早期初始化
    return 0;
}

static struct sbi_platform myplatform = {
    .name = "My Platform",
    .early_init = myplatform_early_init,
    // ... 其他回调
};

const struct sbi_platform *sbi_platform_ptr(void) {
    return &myplatform;
}
```

### 6.4 模板参考

官方提供了完整的移植模板：
- **路径**: `platform/template/platform.c`
- **行数**: 157 行（含详细注释）
- **内容**: 包含所有必要的回调函数模板

---

## 七、Domain Support（域支持）

### 7.1 域概念

**OpenSBI 域**是系统级分区，具有独立的内存区域和 HART 集合，通过 PMP/ePMP/IOPMP 实现安全隔离。

### 7.2 核心数据结构

**域内存区域**:
```c
struct sbi_domain_memregion {
    unsigned long order;      // 2^order 大小
    unsigned long base;       // 基址 (2^order 对齐)
    unsigned long flags;      // RAM/MMIO, R/W/X 权限
};
```

**域实例**:
```c
struct sbi_domain {
    unsigned long index;      // 逻辑索引
    const char *name;         // 域名
    struct sbi_hartmask assigned_harts;   // 分配的 HARTs
    struct sbi_hartmask possible_harts;   // 可能的 HARTs
    struct sbi_domain_memregion *regions; // 内存区域数组
    
    unsigned long boot_hartid;    // 启动 HART
    unsigned long next_addr;      // 下一阶段地址
    unsigned long next_arg1;      // 下一阶段参数
    unsigned long next_mode;      // S-mode 或 U-mode
    
    bool system_reset_allowed;
    bool system_suspend_allowed;
};
```

### 7.3 ROOT 域

默认分配给所有 HART 的域：
- **index**: 0
- **name**: "root"
- **regions**: 保护固件的 region + 全地址空间访问 region

### 7.4 设备树配置示例

```dts
/chosen {
    opensbi-domains {
        compatible = "opensbi,domain,config";
        
        // 内存区域定义
        secure_mem: secure-mem {
            compatible = "opensbi,domain,memregion";
            base = <0x0 0x80000000>;
            order = <20>;  // 1MB
            mmio;
        };
        
        // 域实例
        trusted-domain {
            compatible = "opensbi,domain,instance";
            possible-harts = <&cpu0>;
            regions = <&secure_mem 0x3f>;  // R/W/X + enforce
            boot-hart = <&cpu0>;
            next-addr = <0x0 0x80200000>;
            next-mode = <0x1>;  // S-mode
            system-reset-allowed;
            system-suspend-allowed;
        };
    };
};

cpus {
    cpu0: cpu@0 {
        reg = <0x00>;
        opensbi-domain = <&trusted-domain>;
    };
};
```

---

## 八、SBI 调用接口

### 8.1 调用约定

```c
// 寄存器使用
a7 = EID;  // Extension ID
a6 = FID;  // Function ID
a0-a5 = 输入参数

// 执行 ecall
asm volatile ("ecall");

// 返回值在 a0/a1
```

### 8.2 常用函数封装

**设置定时器**:
```c
void sbi_set_timer(u64 next_time) {
    sbi_ecall(SBI_EXT_0_2_SET_TIMER, 0, next_time, 0, 0, 0, 0, 0);
}
```

**发送 IPI**:
```c
void sbi_send_ipi(u32 target_hart) {
    sbi_ecall(SBI_EXT_0_3_IPI, 0, target_hart, 0, 0, 0, 0, 0);
}
```

**远程 FENCE**:
```c
void sbi_remote_fence(u32 hart_mask) {
    sbi_ecall(SBI_EXT_0_4_RFENCE, SBI_RFENCE_FENCE_I, 
              hart_mask, 0, 0, 0, 0, 0);
}
```

**启动 Hart**:
```c
int sbi_hart_start(u32 hartid, ulong start_addr, ulong priv) {
    return sbi_ecall(SBI_EXT_0_5_HSM, SBI_HSM_HART_START, 
                     hartid, start_addr, priv, 0, 0, 0);
}
```

**系统重置**:
```c
void sbi_system_reset(u32 reset_type, u32 reason) {
    sbi_ecall(SBI_EXT_0_6_SYSTEM_RESET, 0, reset_type, reason, 0, 0, 0, 0);
}
```

---

## 九、编译与配置

### 9.1 基本编译参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `PLATFORM` | 目标平台 | generic |
| `FW_TEXT_START` | 固件加载地址 | 0x0 |
| `FW_FDT_PATH` | 外部 FDT 文件路径 | - |
| `FW_OPTIONS` | 运行时选项 | 0x0 |
| `CROSS_COMPILE` | 交叉编译工具链前缀 | - |

### 9.2 编译示例

**编译 FW_PAYLOAD 固件**:
```bash
make CROSS_COMPILE=riscv64-unknown-elf- \
     PLATFORM=generic \
     FW_PAYLOAD=y \
     FW_PAYLOAD_PATH=./Image \
     FW_PAYLOAD_OFFSET=0x200000 \
     FW_FDT_PATH=./work.dtb
```

**编译 FW_DYNAMIC 固件**:
```bash
make CROSS_COMPILE=riscv64-unknown-elf- \
     PLATFORM=generic \
     FW_DYNAMIC=y
```

**Nuclei UX600 平台**:
```bash
make PLATFORM=nuclei/ux600 clean all
```

### 9.3 配置菜单

```bash
# 图形化配置
make PLATFORM=<platform> menuconfig

# 使用自定义默认配置
make PLATFORM=<platform> PLATFORM_DEFCONFIG=<custom_defconfig>
```

### 9.4 运行时选项

```c
enum sbi_scratch_options {
    SBI_SCRATCH_DISABLE_BOOT_PRINT    = 1 << 0,  // 禁用启动打印
    SBI_SCRATCH_DISABLE_LOCK_PRINT    = 1 << 1,  // 禁用锁打印
    SBI_SCRATCH_ENABLE_LOG_LEVEL      = 1 << 2,  // 启用日志级别
};
```

---

## 十、学习路径建议

### 10.1 入门阶段

1. **阅读 `README.md`**
   - 了解项目架构和编译方法

2. **理解固件类型**
   - 阅读 `docs/firmware/fw.md`
   - 对比三种固件类型的适用场景

3. **第一次编译**
   ```bash
   make PLATFORM=generic
   ```

### 10.2 进阶阶段

4. **研究示例代码**
   - `firmware/payloads/test_main.c` - SBI 调用示例
   - `platform/template/platform.c` - 平台移植模板

5. **理解库接口**
   - 阅读 `docs/library_usage.md`
   - 研究 `include/sbi/sbi_platform.h`

6. **深入学习 SBI 扩展**
   - HSM、PMU、IPI、RFENCE
   - 阅读 `lib/sbi/sbi_ecall_*.c`

### 10.3 实践阶段

7. **平台移植实践**
   - 阅读 `docs/platform_guide.md`
   - 参考 `platform/template/platform.c`
   - 尝试为新平台添加支持

8. **高级特性**
   - 学习 `docs/domain_support.md`
   - 研究系统级分区实现

### 10.4 深入阶段

9. **阅读源码**
   - `lib/sbi/sbi_init.c` - 初始化流程
   - `lib/sbi/sbi_hsm.c` - Hart 状态管理
   - `lib/sbi/sbi_domain.c` - 域管理

10. **参与社区**
    - 邮件列表: opensbi@lists.infradead.org
    - GitHub: https://github.com/riscv-software-src/opensbi

---

## 十一、Nuclei 平台特定信息

### 11.1 Nuclei UX600 平台

**平台特性**:
- 64-bit RISC-V 核心
- 支持 Linux 运行
- 单核，6~9 级可变流水线
- 顺序发射、乱序写回
- 运行频率可达 >1.2GHz

**构建命令**:
```bash
make PLATFORM=nuclei/ux600 clean all
```

**相关文档**:
- `docs/platform/nuclei_ux600.md`
- `platform/nuclei/ux600/platform.c`

### 11.2 Nuclei 串口驱动

- `lib/utils/serial/nuclei-uart.c`
- `include/sbi_utils/serial/nuclei-uart.h`

### 11.3 Nuclei Eval SoC 支持

- `platform/generic/nuclei/`

---

## 十二、常见问题

### Q1: 如何选择固件类型？

- **FW_DYNAMIC**: 前级引导程序（如 U-Boot SPL）能够加载多段镜像
- **FW_JUMP**: 固件加载地址固定，但前级无法加载下一阶段
- **FW_PAYLOAD**: 前级引导程序能力受限，需要固件自己包含下一阶段

### Q2: Linux 内核需要支持 HSM 扩展吗？

- Linux v5.7-rc1+ 已原生支持 HSM 扩展
- 旧版本 Linux 需要使用 OpenSBI v0.6 或更新版本

### Q3: 如何为新平台添加支持？

参考 `platform/template/platform.c`（157行详细注释的模板），按照「平台移植指南」章节的步骤操作。

### Q4: OpenSBI 支持哪些中断控制器？

- PLIC（平台级中断控制器）
- APLIC（高级 PLIC）
- IMSIC（消息信号中断控制器）

### Q5: 如何生成文档？

```bash
# 生成 Doxygen 文档
make docs

# 生成的文档在 build/docs/latex/refman.pdf
```

---

## 十三、参考资源汇总

### 13.1 在线资源

| 资源 | URL |
|------|-----|
| OpenSBI GitHub | https://github.com/riscv-software-src/opensbi |
| SBI 规范 | https://github.com/riscv-non-isa/riscv-sbi-doc |
| SBI v3.0 PDF | https://docs.riscv.org/reference/platform-software/sbi/_attachments/riscv-sbi.pdf |
| RISC-V SBI Wiki | https://riscv.atlassian.net/wiki/spaces/HOME/pages/810057837/ |

### 13.2 本地关键文件

| 文件 | 路径 | 说明 |
|------|------|------|
| 项目总览 | `README.md` | 快速入门 |
| 固件类型 | `docs/firmware/fw.md` | 固件详解 |
| 平台移植 | `docs/platform_guide.md` | 移植指南 |
| 域支持 | `docs/domain_support.md` | 分区详解 |
| 平台 API | `include/sbi/sbi_platform.h` | 接口定义 |
| 移植模板 | `platform/template/platform.c` | 新平台参考 |
| Nuclei 平台 | `docs/platform/nuclei_ux600.md` | Nuclei 专用 |

---

## 十四、文档版本信息

- **文档版本**: 1.0
- **生成日期**: 2025年
- **基于 OpenSBI**: 本地代码库版本
- **适用 SBI 规范**: v0.2 / v1.0 / v2.0 / v3.0

---

## 十五、附录：术语表

| 术语 | 全称 | 说明 |
|------|------|------|
| **SBI** | Supervisor Binary Interface | 监管者二进制接口 |
| **OpenSBI** | Open Source SBI | RISC-V SBI 开源实现 |
| **HART** | Hardware Thread | 硬件线程（RISC-V CPU 核心） |
| **FDT** | Flattened Device Tree | 扁平设备树 |
| **PMP** | Physical Memory Protection | 物理内存保护 |
| **PLIC** | Platform Level Interrupt Controller | 平台级中断控制器 |
| **HSM** | Hart State Management | Hart 状态管理 |
| **PMU** | Performance Monitoring Unit | 性能监控单元 |
| **IPI** | Inter-Processor Interrupt | 处理器间中断 |
| **RFENCE** | Remote FENCE | 远程内存屏障 |
| **Domain** | - | OpenSBI 系统级分区 |

---

*本文档由 OpenCode AI 生成，基于对 OpenSBI 官方文档和本地代码库的全面分析。*
