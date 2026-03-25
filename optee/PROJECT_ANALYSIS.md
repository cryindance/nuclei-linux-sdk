# OP-TEE RISC-V 项目分析文档

> 生成时间：2026-03-12  
> 项目路径：`/home/jingo/work/nuclei-linux-sdk/optee`  
> 远程仓库：`git@github.com:Nuclei-Software/nuclei-linux-sdk.git`

---

## 1. 项目概述

本项目是 **芯来科技（Nuclei）** 基于 **RISC-V 架构** 实现的 **OP-TEE（Open Portable Trusted Execution Environment）** 可信执行环境。

### 1.1 核心特性

- **架构**：RISC-V 64位（RV64IMAFDC）
- **多核支持**：最多 8 核心 SMP
- **双世界模型**：安全世界（TEE）与非安全世界（REE）隔离
- **中断隔离**：通过 PLIC 实现安全/非安全中断路由
- **内存隔离**：通过 PMP（Physical Memory Protection）隔离地址空间
- **标准兼容**：GlobalPlatform TEE 标准

### 1.2 安全机制

```
┌─────────────────────────────────────────────────────────────┐
│        Normal World (REE) - 非安全世界                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Linux OS (S-mode)                       │   │
│  │  ┌───────────────┐  ┌───────────────────────────┐   │   │
│  │  │ tee-supplicant│  │      Applications         │   │   │
│  │  └───────────────┘  └───────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────────┘
                        │  SBI (ecall)
┌───────────────────────┼─────────────────────────────────────┐
│           OpenSBI (M-mode) - 安全监控器                      │
│     负责：上下文切换、世界切换、中断路由                       │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────┼─────────────────────────────────────┐
│       OP-TEE OS (S-mode) - 安全世界                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │     Trusted Applications (TAs)                      │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐     │   │
│  │  │hello_world│ │secure_storage│ │    crypto      │    │   │
│  │  └──────────┘ └──────────┘ └──────────────────┘     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 项目结构

```
optee/
├── optee_os/              # OP-TEE 安全操作系统核心
│   ├── core/              # 核心代码
│   │   └── arch/riscv/    # RISC-V 架构特定代码
│   │       ├── plat-nuclei/   # 芯来平台实现
│   │       ├── kernel/        # 内核（线程、启动、中断）
│   │       ├── mm/            # 内存管理
│   │       └── tee/           # TEE 核心
│   ├── ta/                # 内置可信应用
│   ├── ldelf/             # TA 加载器
│   └── lib/               # 库（mbedtls 等）
│
├── optee_client/          # 客户端库与工具
│   ├── libteec/           # TEE 客户端 API 库
│   ├── libckteec/         # PKCS#11 接口
│   ├── libseteec/         # 安全元素接口
│   └── tee-supplicant/    # 用户空间守护进程
│
├── optee_examples/        # 示例应用程序
│   ├── hello_world/       # 基础示例
│   ├── demo/              # 安全中断测试
│   ├── secure_storage/    # 安全存储示例
│   ├── acipher/           # 非对称加密
│   ├── aes/               # 对称加密
│   ├── random/            # 随机数生成
│   ├── hotp/              # HOTP 一次性密码
│   └── plugins/           # 插件示例
│
├── optee_test/            # 测试套件
│   ├── host/xtest/        # 测试主机程序
│   └── ta/                # 测试用 TA
│
└── optee_benchmark/       # 性能测试工具
    └── libyaml/           # YAML 解析库
```

---

## 3. 架构详解

### 3.1 内存布局（evalsoc 平台）

| 镜像 | 基地址 | 大小 | 说明 |
|------|--------|------|------|
| OpenSBI | `0xA0000000` | 2MB | M 模式固件，常驻内存 |
| OP-TEE Shared Memory | `0xA0200000` | 2MB | TEE/REE 共享内存 |
| OP-TEE TZDRAM | `0xA0800000` | 8MB | TEE 安全内存 |
| U-Boot | `0xA1000000` | 4MB | 引导加载器 |
| Kernel | `0xA1400000` | 50MB | Linux 内核 |
| FDT | `0xA8000000` | 1MB | 设备树 |
| RootFS | `0xA8300000` | ~1.5GB | 根文件系统 |

### 3.2 关键组件说明

#### 3.2.1 OP-TEE OS 核心

**文件位置**：`optee_os/core/arch/riscv/`

| 文件/目录 | 功能 |
|-----------|------|
| `plat-nuclei/` | 芯来平台特定代码 |
| `kernel/boot.c` | 启动流程初始化 |
| `kernel/entry.S` | 入口汇编代码 |
| `kernel/thread.c` | 线程管理 |
| `kernel/thread_rv.S` | RISC-V 线程上下文切换 |
| `kernel/sbi.c` | OpenSBI 接口 |
| `mm/` | 内存管理（MMU、PMP） |

#### 3.2.2 平台配置（plat-nuclei）

**文件**：`optee_os/core/arch/riscv/plat-nuclei/conf.mk`

关键配置项：
```makefile
CFG_RV64_core ?= y              # RISC-V 64位
CFG_TEE_CORE_NB_CORE=8          # 8核心支持
CFG_NUM_THREADS=4               # 4线程
CFG_RISCV_MMU_MODE=39           # 39位 MMU
CFG_WITH_USER_TA=y              # 支持用户 TA
CFG_SHART_FEATURE=y             # 支持 shartid CSR
CFG_TZDRAM_START=0x41800000     # TEE 内存起始
CFG_TZDRAM_SIZE=0x00800000      # TEE 内存大小
```

#### 3.2.3 中断处理

**文件**：`optee_os/core/arch/riscv/plat-nuclei/main.c`

```c
// PLIC 中断处理函数
void itr_core_handler(void) {
    // 1. 获取当前 hart ID
    // 2. 从 PLIC claim 中断号
    // 3. 处理中断（如 timer 中断 38/39）
    // 4. 向 PLIC complete 中断
}
```

### 3.3 启动流程

```
1. freeloader 从 Flash 加载镜像到 DDR
         ↓
2. OpenSBI 初始化平台
   - 初始化 PMP
   - 设置中断路由
   - 通过 mret 进入 OP-TEE
         ↓
3. OP-TEE OS 初始化
   - 初始化 MMU/PMP
   - 初始化中断控制器
   - 初始化线程
   - ecall 返回 OpenSBI
         ↓
4. OpenSBI 启动 U-Boot
         ↓
5. U-Boot 启动 Linux
         ↓
6. Linux 加载 OP-TEE 驱动
   - 识别 firmware 节点
   - 启动 tee-supplicant
         ↓
7. 系统就绪，可运行 TA
```

---

## 4. 编译系统

### 4.1 编译依赖关系

```
┌─────────────────────────────────────────────────────────────┐
│                      编译流程                                 │
└──────────────┬──────────────────────────────────────────────┘
               │
    ┌──────────┴───────────────────────────────────────────┐
    ▼                                                      ▼
┌──────────────────────┐                      ┌──────────────────────┐
│ 1. optee_os          │                      │ 2. optee_client      │
│    编译 TEE 内核      │                      │    编译客户端库       │
│    输出：            │                      │    输出：            │
│    - tee.bin         │                      │    - libteec.so      │
│    - ta_dev_kit/     │                      │    - tee-supplicant  │
└──────────┬───────────┘                      └──────────┬───────────┘
           │                                             │
           ▼                                             ▼
┌──────────────────────┐                      ┌──────────────────────┐
│ 3. optee_examples    │                      │ 4. optee_test        │
│    编译示例应用       │                      │    编译测试套件       │
│    依赖：            │                      │    依赖：            │
│    - ta_dev_kit      │                      │    - ta_dev_kit      │
│    - libteec         │                      │    - libteec         │
└──────────────────────┘                      └──────────────────────┘
```

### 4.2 各组件编译

#### 4.2.1 OP-TEE OS

```bash
cd optee/optee_os
make PLATFORM=nuclei \
     CROSS_COMPILE=riscv-nuclei-linux-gnu- \
     CFG_TEE_CORE_LOG_LEVEL=3 \
     O=out
```

**输出文件**：
- `out/tee.bin` - TEE 内核镜像
- `out/ta_dev_kit/` - TA 开发套件
- `out/export-ta_arm64/` - 导出文件

#### 4.2.2 OP-TEE Client

```bash
cd optee/optee_client
make CROSS_COMPILE=riscv-nuclei-linux-gnu- \
     CFG_TEE_CLIENT_LOG_LEVEL=3 \
     O=out

# 安装到 rootfs
make install DESTDIR=<rootfs_path>
```

**编译顺序**：
1. `build-libteec` - 客户端库
2. `build-tee-supplicant` - 守护进程（依赖 libteec）
3. `build-libckteec` - PKCS#11 库（依赖 libteec）
4. `build-libseteec` - 安全元素库（依赖 libteec）

**安装位置**：
- `/usr/lib/libteec.so*` - 客户端库
- `/usr/sbin/tee-supplicant` - 守护进程
- `/usr/include/*.h` - 头文件

#### 4.2.3 OP-TEE Examples

每个示例包含 Host（CA）和 TA 两部分：

```bash
cd optee/optee_examples/hello_world

# 编译 Host（CA）
make -C host \
     CROSS_COMPILE=riscv-nuclei-linux-gnu- \
     TEEC_EXPORT=<optee_client>/out/export

# 编译 TA
make -C ta \
     CROSS_COMPILE=riscv-nuclei-linux-gnu- \
     TA_DEV_KIT_DIR=<optee_os>/out/ta_dev_kit

# 或一次编译全部
make CROSS_COMPILE=riscv-nuclei-linux-gnu- \
     TA_DEV_KIT_DIR=<optee_os>/out/ta_dev_kit \
     TEEC_EXPORT=<optee_client>/out/export
```

**Host 编译关键变量**：
```makefile
CC = riscv-nuclei-linux-gnu-gcc
CFLAGS = -I../ta/include -I$(TEEC_EXPORT)/include
LDADD = -lteec -L$(TEEC_EXPORT)/lib
OUTPUT = optee_example_hello_world
```

**TA 编译关键变量**：
```makefile
# UUID 必须唯一
BINARY=8aaaf200-2450-11e4-abe2-0002a5d5c51b

# 包含 TA 开发套件 Makefile
TA_DEV_KIT_DIR=<optee_os>/out/ta_dev_kit
include $(TA_DEV_KIT_DIR)/mk/ta_dev_kit.mk
```

**输出文件**：
- `host/optee_example_hello_world` - CA 可执行文件
- `ta/8aaaf200-2450-11e4-abe2-0002a5d5c51b.ta` - 签名后的 TA

#### 4.2.4 OP-TEE Test

```bash
cd optee/optee_test
make CROSS_COMPILE=riscv-nuclei-linux-gnu- \
     TA_DEV_KIT_DIR=<optee_os>/out/ta_dev_kit \
     OPTEE_CLIENT_EXPORT=<optee_client>/out/export \
     O=out

# 安装测试 TA
make install DESTDIR=<rootfs_path>
```

**输出文件**：
- `out/xtest` - 测试主机程序
- `out/*.ta` - 测试用可信应用

### 4.3 集成编译（Linux SDK）

在 Linux SDK 顶层目录：

```bash
# 编译 freeloader
make SOC=evalsoc CORE=ux900fd BOOT_MODE=sd freeloader

# 编译所有启动镜像（包含 OP-TEE）
make SOC=evalsoc CORE=ux900fd BOOT_MODE=sd bootimages
```

**编译顺序**：
1. `optee_os` → `tee.bin`
2. `optee_client` → 库和守护进程
3. `optee_examples` → 示例应用
4. `optee_test` → 测试套件
5. 安装所有组件到 rootfs

### 4.4 关键编译变量

| 变量 | 说明 | 示例值 |
|------|------|--------|
| `CROSS_COMPILE` | 交叉编译器前缀 | `riscv-nuclei-linux-gnu-` |
| `PLATFORM` | OP-TEE 平台 | `nuclei` |
| `O` | 输出目录 | `out` |
| `TA_DEV_KIT_DIR` | TA 开发套件路径 | `optee_os/out/ta_dev_kit` |
| `TEEC_EXPORT` | Client 库导出路径 | `optee_client/out/export` |
| `OPTEE_CLIENT_EXPORT` | Client 导出路径（test 用） | `optee_client/out/export` |
| `CFG_TEE_CORE_LOG_LEVEL` | 核心日志级别 | `0-4` |
| `CFG_TEE_CLIENT_LOG_LEVEL` | 客户端日志级别 | `0-4` |

---

## 5. 示例程序说明

### 5.1 示例列表

| 示例 | 功能 | 说明 |
|------|------|------|
| `hello_world` | 基础示例 | 递增数值，演示基本调用流程 |
| `demo` | 安全中断测试 | 使用 38 号中断测试安全中断处理 |
| `secure_storage` | 安全存储 | 演示 TEE 安全存储 API |
| `acipher` | 非对称加密 | RSA/ECC 加密操作 |
| `aes` | 对称加密 | AES 加密/解密 |
| `random` | 随机数 | 生成随机数 |
| `hotp` | HOTP | 基于计数器的一次性密码 |
| `plugins` | 插件系统 | 演示插件机制 |

### 5.2 Hello World 示例结构

```
hello_world/
├── host/
│   ├── Makefile              # Host 编译脚本
│   └── main.c                # Client Application 代码
│       ├── TEEC_InitializeContext()  # 初始化上下文
│       ├── TEEC_OpenSession()        # 打开会话
│       ├── TEEC_InvokeCommand()      # 调用命令
│       └── TEEC_CloseSession()       # 关闭会话
│
└── ta/
    ├── Makefile              # TA 编译脚本
    ├── hello_world_ta.c      # Trusted Application 代码
    │   ├── TA_CreateEntryPoint()     # TA 创建入口
    │   ├── TA_OpenSessionEntryPoint() # 会话入口
    │   ├── inc_value()               # 处理命令
    │   └── TA_DestroyEntryPoint()    # TA 销毁
    ├── include/hello_world_ta.h     # TA 接口定义
    └── user_ta_header_defines.h     # TA 头定义
```

### 5.3 运行示例

```bash
# 在目标板上运行
root@nucleisys:~# optee_example_hello_world
D/TA:  TA_CreateEntryPoint:39 has been called
D/TA:  TA_OpenSessionEntryPoint:68 has been called
I/TA: Hello World!
Invoking TA to increment 42
D/TA:  inc_value:105 has been called
I/TA: Got value: 42 from NW
I/TA: Increase value to: 43
TA incremented value to 43
I/TA: Goodbye!
D/TA:  TA_DestroyEntryPoint:50 has been called
```

---

## 6. 配置文件详解

### 6.1 平台配置

**文件**：`optee_os/core/arch/riscv/plat-nuclei/conf.mk`

```makefile
# 架构配置
CFG_RV64_core ?= y                      # 64位 RISC-V
$(call force,CFG_RISCV_MMU_MODE,39)    # 39位 MMU
$(call force,CFG_RISCV_TIME_SOURCE_RDTIME,y)

# 核心配置
$(call force,CFG_TEE_CORE_NB_CORE,8)   # 8核心
$(call force,CFG_NUM_THREADS,4)        # 4线程
$(call force,CFG_WITH_USER_TA,y)       # 支持用户 TA
$(call force,CFG_WITH_SOFTWARE_PRNG,y) # 软件随机数

# 内存配置
CFG_TZDRAM_START ?= 0x41800000         # TEE 内存起始
CFG_TZDRAM_SIZE  ?= 0x00800000         # TEE 内存大小 8MB
CFG_SHMEM_START  ?= 0x41200000         # 共享内存起始
CFG_SHMEM_SIZE   ?= 0x00200000         # 共享内存大小 2MB

# 特性开关
$(call force,CFG_SHART_FEATURE,y)      # 支持 shartid CSR
$(call force,CFG_WITH_ARM_TRUSTED_FW,y) # 兼容 ATF 模式
```

### 6.2 平台头文件

**文件**：`optee_os/core/arch/riscv/plat-nuclei/platform_config.h`

```c
// PLIC 基地址
#define PLIC_BASE           0x1C000000

// Timer 基地址
#define TIMER_BASE          0x10012000

// UART 基地址
#define UART_BASE           0x10013000
```

### 6.3 内核链接脚本

**文件**：`optee_os/core/arch/riscv/plat-nuclei/kern.ld.S`

定义了 TEE 内核的内存布局和段分布。

---

## 7. 调试与日志

### 7.1 日志级别

| 级别 | 值 | 说明 |
|------|-----|------|
| `NONE` | 0 | 无日志 |
| `ERROR` | 1 | 仅错误 |
| `INFO` | 2 | 信息和错误 |
| `DEBUG` | 3 | 调试、信息、错误 |
| `FLOW` | 4 | 全部（包括函数流程） |

### 7.2 启用调试

```bash
# 编译时设置日志级别
make CFG_TEE_CORE_LOG_LEVEL=3    # TEE 核心日志
make CFG_TEE_CLIENT_LOG_LEVEL=3  # 客户端日志
make CFG_TEE_TA_LOG_LEVEL=4      # TA 日志
```

### 7.3 日志输出

TEE 核心日志通过 UART 输出：
```
I/TC: OP-TEE version: 80ac73cea-dev
I/TC: Primary CPU initializing
I/TC: Primary CPU switching to normal world boot
```

TA 日志同样通过 UART：
```
D/TA:  TA_CreateEntryPoint:39 has been called
I/TA: Hello World!
```

---

## 8. 移植指南

### 8.1 移植前提

**硬件要求**：
- CPU：Nuclei 900 系列（RISC-V）
- PMP Entry：至少 4 个
- PLIC：M 模式 pending 可写
- shartid CSR（可选，< v2.8.0 可禁用）

**软件要求**：
- Linux 5.10+
- OpenSBI v0.9+
- U-Boot 2021.01+

### 8.2 移植步骤

1. **创建平台目录**：
   ```bash
   mkdir -p optee_os/core/arch/riscv/plat-<your_platform>
   ```

2. **创建必要文件**：
   ```
   plat-<your_platform>/
   ├── conf.mk              # 编译配置
   ├── platform_config.h    # 平台地址定义
   ├── main.c               # 平台特定代码
   ├── kern.ld.S            # 链接脚本
   └── sub.mk               # 子目录 Makefile
   ```

3. **修改配置文件**：
   - 配置内存地址
   - 配置外设地址
   - 配置 CPU 核心数

4. **修改 Linux SDK**：
   - `Makefile`：设置 `optee_os_platform`
   - `conf/<soc>/build.mk`：配置 kernel 地址
   - `conf/<soc>/linux_*.defconfig`：启用 `CONFIG_OPTEE=y`
   - `conf/<soc>/*.dts`：添加 optee firmware 节点
   - `opensbi/config.mk`：配置 optee 地址

---

## 9. 常见问题

### 9.1 编译错误

**问题**：找不到 `ta_dev_kit.mk`  
**解决**：确保先编译 `optee_os`，且 `TA_DEV_KIT_DIR` 路径正确

**问题**：Python 模块缺失  
**解决**：安装必要模块：
```bash
pip3 install pyelftools cryptography
```

### 9.2 运行时问题

**问题**：OP-TEE 驱动加载失败  
**解决**：
1. 检查 device tree 中 optee 节点
2. 检查内核配置 `CONFIG_OPTEE=y`
3. 检查内存地址配置是否一致

**问题**：TA 加载失败  
**解决**：
1. 检查 TA 是否已签名
2. 检查 UUID 是否唯一
3. 检查 `/lib/optee_armtz/` 目录权限

---

## 10. 参考资源

- **OP-TEE 官方文档**：https://optee.readthedocs.io/
- **芯来科技**：https://www.nucleisys.com/
- **RISC-V 规范**：https://riscv.org/specifications/
- **GlobalPlatform TEE 规范**：https://globalplatform.org/specs-library/

---

## 11. 文件统计

- **源代码文件**：约 2,298+ 个（仅 optee_os）
- **主要语言**：C、汇编（RISC-V）
- **代码行数**：约数十万行

---

*本文档由 AI 助手自动生成，基于代码仓库实际内容分析*
