# U-Boot Nuclei HSM 分支代码修改分析

**文档日期**: 2026-04-03  
**分支**: dev_hsm  
**作者**: cryindance  
**分析**: Sisyphus Agent

---

## 📋 修改概览

本次提交包含 **6 个原子提交**，涉及 RISC-V CPU 启动、板级初始化、Mailbox HSM 安全模块和文档更新。

```
commit 3945148f30 docs: add Nuclei SPL development guides
commit bad3f590b8 drivers/serial: fix whitespace alignment
commit 21721db958 drivers/crypto/nuclei: update mailbox driver
commit 5f92eb9b1a doc/sphinx: add execfile_ compatibility
commit 469c5ebfed board/nuclei: update SPL configuration
commit 5ae3252811 arch/riscv: add hartid mask support
```

---

## 1️⃣ RISC-V CPU 启动层修改

### 1.1 文件位置
- `arch/riscv/cpu/start.S` - 统一入口点
- `arch/riscv/cpu/nuclei/spl.c` - Nuclei SoC 初始化

### 1.2 修改内容

#### start.S - Hart ID 掩码处理

```asm
#define MHARTID_MASK 0x3

/* define hartid mask bits */
#ifndef MHARTID_MASK
#error "MHARTID_MASK is not defined!"
#else
#define HARTID_MASK      MHARTID_MASK
#endif

.macro GET_MASKED_HARTID result_reg
    # Read hartid into result register
    csrr    \result_reg, mhartid
    and     \result_reg, \result_reg, HARTID_MASK
.endm

_start:
#if CONFIG_IS_ENABLED(RISCV_MMODE)
    GET_MASKED_HARTID       a0
#endif
```

### 1.3 技术分析

#### 为什么需要 Hart ID 掩码？

**背景**: RISC-V 的 `mhartid` CSR 返回完整的 Hart ID，但在多核 SoC 中：
- 物理 Hart ID 可能包含簇/cluster 信息（高位）
- 实际逻辑 Hart ID 只需要低位（0-3 表示 4 核）

**作用**: 
1. `MHARTID_MASK 0x3` - 掩码保留低 2 位（支持最多 4 核）
2. `GET_MASKED_HARTID` 宏 - 读取 mhartid 并应用掩码
3. 确保 U-Boot 只看到逻辑 Hart ID（0-3），避免多核调度问题

#### spl.c - 调试注释

```c
int spl_soc_init(void)
{
    // ... DRAM init ...
    //printf("spl_soc_init\n");      // 调试标记
    return 0;
}

void harts_early_init(void)
{
    //printf("harts_early_init\n");  // 调试标记
}
```

**作用**: 添加注释掉的 printf 语句，方便后续调试时快速启用

---

## 2️⃣ 板级初始化修改

### 2.1 文件位置
- `board/nuclei/generic/spl.c` - 板级 SPL 初始化
- `board/nuclei/generic/Kconfig` - 配置更新
- `configs/nuclei_generic_defconfig` - 默认配置

### 2.2 修改内容

#### spl.c - MATTRI0 邮箱初始化

```c
int spl_board_init_f(void)
{
    #define CCM_SUEN    0x7CE
    #define CCM_SEN     0x2020202
    csr_write(CCM_SUEN, CCM_SEN);   // 启用 S-mode CCM

    #define MATTRI0_MASK    0x7F4
    #define MATTRI0_BASE    0x7F3
    #define HOST_MAILBOX_BASE_ADDR  (0x8800000UL)
    #define HOST_MAILBOX_SIZE       (0x4000ULL)

    uint64_t base_val;
    base_val = (HOST_MAILBOX_BASE_ADDR & (~(HOST_MAILBOX_SIZE-1))) | BIT(2) | BIT(0);

    csr_write(MATTRI0_MASK, ~(HOST_MAILBOX_SIZE-1));  // 设置掩码
    csr_write(MATTRI0_BASE, base_val);                 // 设置基址

    return 0;
}
```

### 2.3 技术分析

MATTRI0 寄存器作用

**MATTRI0 (Memory Attribute Table Region Index 0)** 是 Nuclei 处理器的内存属性配置寄存器：

| 寄存器 | CSR 地址 | 作用 |
|--------|----------|------|
| `MATTRI0_MASK` | 0x7F4 | 区域掩码，定义内存区域大小和对齐 |
| `MATTRI0_BASE` | 0x7F3 | 区域基址，定义内存区域起始地址 |

**配置逻辑**:
```
base_val = (0x8800000 & ~0x3FFF) | BIT(2) | BIT(0)
         = 0x8800000 | 0x4 | 0x1
         = 0x8800005
```

- `BIT(0) = 1` - 启用该区域
- `BIT(2) = 1` - 设备内存属性（Device Memory）
- 掩码 `~0x3FFF` - 16KB 对齐（0x4000 = 16KB）

**目的**: 为 HSM（Hardware Security Module）Mailbox 配置内存映射区域，使 CPU 可以通过 0x8800000 地址访问安全子系统的共享内存。

#### Kconfig - SPL 加载地址变更

```diff
 config SPL_TEXT_BASE
-    default 0x80000000
+    default 0x90000000
```

**原因**: 
- 原地址 0x80000000 可能与 Boot ROM 或其他固件冲突
- 新地址 0x90000000 为 SPL 提供独立的内存区域
- 避免与 HSM 邮箱区域（0x8800000）重叠

---

## 3️⃣ Mailbox HSM 驱动修改

### 3.1 文件位置
- `drivers/crypto/nuclei/mailbox.h` - 邮箱基址定义
- `drivers/crypto/nuclei/mailbox.c` - 高层接口
- `drivers/crypto/nuclei/mailbox_lowlevel.c` - 底层操作

### 3.2 修改内容

#### mailbox.h - 基址更新

```diff
-#define CORE0_PPI_RAM_BASE                        (0x97000000UL)
+#define CORE0_PPI_RAM_BASE                        (0x8800000UL)
```

#### mailbox_lowlevel.c - 调试代码

```c
#include <string.h>
#include <linux/delay.h>

void MAILBOX_HostWriteDataToMailboxIn(...)
{
    //printf("addr:%p,buf:%p\n",addr,buf);      // 调试: 地址打印
    //delay_u(200);                              // 调试: 延迟
    
    for (i = 0; i < len; i++) {
        addr[i] = buf[i];  
        //mdelay(1);                             // 调试: 逐字延迟
        //printf("i=%d\n",i);                     // 调试: 索引打印
    }
    
    asm volatile ("fence");
    //printf("buf to addr finish.\n");            // 调试: 完成标记
    MAILBOX_SetMbxInFull(mailbox, mbx_num);
    //printf("MAILBOX_SetMbxInFull finish.\n");  // 调试: 状态标记
    asm volatile ("fence");
    //printf("fence finish.\n");                  // 调试: 屏障完成
}
```

### 3.3 技术分析

#### 地址变更原因

| 地址 | 用途 | 说明 |
|------|------|------|
| 0x97000000 | 旧地址 | 可能与 DDR 区域冲突 |
| 0x8800000  | 新地址 | 与 MATTRI0 配置一致，专用安全区域 |

**关键**: Mailbox 基址必须与 `MATTRI0_BASE` 配置的地址一致，否则 CPU 无法访问 HSM 共享内存。

#### Mailbox 通信协议

**主机 → HSM 安全子系统**:
```
CPU (Host)                              HSM (Secure)
    |                                       |
    |---- Write command to mailbox.in ---->|
    |---- Set mbx_in_full bit ----------->|
    |                                       |
    |<--- Read response from mailbox.out---|
    |<--- mbx_out_full bit ---------------|
```

**关键操作**:
1. `MAILBOX_HostLinkToMbx()` - 建立与邮箱的连接
2. `MAILBOX_HostWriteDataToMailboxIn()` - 写入命令
3. `MAILBOX_SetMbxInFull()` - 通知 HSM 有新命令
4. `MAILBOX_GetMbxOutFullStatus()` - 轮询响应
5. `MAILBOX_HostReadDataFromMailboxOut()` - 读取响应

#### 安全服务类型

```c
#define SECURE_SERVICE_OPCODE_HASH      1   // 哈希运算
#define SECURE_SERVICE_OPCODE_CRYP      2   // 对称加密
#define SECURE_SERVICE_OPCODE_ACRYP     3   // 非对称加密
#define SECURE_SERVICE_OPCODE_TRNG      4   // 真随机数
#define SECURE_SERVICE_OPCODE_EFUSE     5   // eFuse 操作
#define SECURE_SERVICE_OPCODE_BOOT      6   // 安全启动
```

---

## 4️⃣ 其他修改

### 4.1 Sphinx 文档兼容性修复

**文件**: `doc/sphinx/load_config.py`

```python
# execfile_ 兼容实现（Sphinx 7.x 已移除该模块）
def execfile_(filepath, namespace):
    with open(filepath, 'rb') as f:
        code = compile(f.read(), filepath, 'exec')
    exec(code, namespace)
```

**原因**: Sphinx 7.x 移除了 `sphinx.util.pycompat.execfile_`，需要本地实现以保持兼容性。

### 4.2 串口驱动格式修复

**文件**: `drivers/serial/serial_nuclei.c`

```diff
 U_BOOT_DRIVER(serial_nuclei) = {
-    .name = "serial_nuclei",
-    .id = UCLASS_SERIAL,
+    .name    = "serial_nuclei",
+    .id      = UCLASS_SERIAL,
     .of_match = nuclei_serial_ids,
     .of_to_plat = nuclei_serial_of_to_plat,
     .plat_auto = sizeof(struct nuclei_uart_plat),
     .probe = nuclei_serial_probe,
-    .ops = &nuclei_serial_ops,
+    .ops     = &nuclei_serial_ops,
 };
```

**作用**: 将空格转换为 Tab，符合 U-Boot 内核代码风格。

---

## 5️⃣ 新增文档

### 5.1 文档清单

| 文档 | 说明 |
|------|------|
| `AGENTS.md` | 项目知识库（根目录） |
| `arch/AGENTS.md` | 架构层知识库 |
| `arch/riscv/AGENTS.md` | RISC-V 架构详细文档 |
| `drivers/AGENTS.md` | 驱动子系统知识库 |
| `tools/AGENTS.md` | 工具链知识库 |
| `NUCLEI_SPL_GUIDE.md` | Nuclei SPL 开发完整指南 |
| `NUCLEI_SPL_CODE_EXPLANATION.md` | 代码逐行解析 |
| `NUCLEI_SPL_images/` | 配套图表目录 |
| `spl_fsm.dot/svg` | SPL 状态机图 |

### 5.2 文档特点

- 采用标准 Markdown 格式
- 使用 Graphviz DOT 生成 SVG 图表
- 配色方案统一（红/蓝/绿/橙）
- 包含启动流程、内存布局、FIT 结构等图表

---

## 📊 修改影响分析

### 功能影响

| 组件 | 影响 | 风险 |
|------|------|------|
| 多核启动 | Hart ID 掩码确保正确识别 | 低 |
| 内存映射 | MATTRI0 配置安全区域 | 中（需验证 HSM 通信） |
| HSM 通信 | Mailbox 地址更新 | 中（需与 HSM 固件匹配） |
| 文档构建 | Sphinx 7.x 兼容 | 低 |

### 依赖关系

```
start.S (Hart ID 掩码)
    │
    ▼
spl.c (MATTRI0 配置) ──→ mailbox.h (基址 0x8800000)
    │                          │
    ▼                          ▼
SPL 初始化完成           HSM 安全服务可用
```

---

## 🎯 总结

本次修改主要围绕 **Nuclei RISC-V SoC 的 HSM（硬件安全模块）集成**：

1. **Hart ID 掩码**: 支持多核系统的正确识别
2. **MATTRI0 配置**: 建立 CPU 与 HSM 的安全通信通道
3. **Mailbox 驱动**: 更新基址并添加调试能力
4. **文档**: 全面完善项目知识库

**关键设计**: CPU 通过内存映射的 Mailbox（0x8800000）与 HSM 安全子系统通信，实现加密、哈希、签名等安全服务。

---

## 📚 参考

- Nuclei RISC-V 处理器手册
- U-Boot 官方文档
- HSM Mailbox 通信协议规范
