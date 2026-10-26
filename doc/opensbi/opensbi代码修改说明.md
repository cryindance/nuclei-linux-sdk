# OpenSBI 代码修改说明文档

**文档日期：** 2025-04-02  
**分支：** dev_hsm  
**修改文件数：** 9个文件（新增93行，删除48行）

---

## 修改概览

本次修改主要涉及以下几个方面的功能增强和优化：

1. **Hart ID 掩码机制** - 支持多核系统中的 Hart ID 映射
2. **OP-TEE 安全监控优化** - 函数重命名和 Mailbox 配置改进
3. **调试信息增强** - 启动流程中增加调试打印
4. **平台特定配置** - Nuclei 平台的 Mailbox 内存属性配置

---

## 详细修改说明

### 1. Hart ID 掩码机制

#### 修改文件
- `firmware/fw_base.S`
- `include/sbi/riscv_asm.h`

#### 实际作用

**背景：** 在支持多核或具有复杂 Hart ID 分配的系统（如 Nuclei 的 TEE/REE 双系统架构）中，原始的 Hart ID 直接使用可能导致问题。

**修改内容：**

1. **定义掩码常量：**
   ```c
   #define MHARTID_MASK 0x3
   ```
   使用 0x3（二进制 0011）作为掩码，意味着只保留 Hart ID 的低 2 位。

2. **修改 Hart ID 获取方式：**
   ```c
   // 修改前
   #define current_hartid()	((unsigned int)csr_read(CSR_MHARTID) & 0xff)
   
   // 修改后
   #define current_hartid()	((unsigned int)(csr_read(CSR_MHARTID)&HARTID_MASK))
   ```

3. **汇编层修改：**
   ```assembly
   // 修改前
   andi	s6, s6, 0xff
   
   // 修改后
   andi s6, s6, MHARTID_MASK
   ```

**实际意义：**
- **支持 TEE/REE 双系统：** 在 Nuclei 的架构中，TEE 侧和 REE 侧可能使用不同的 Hart ID 编号空间，通过掩码可以将它们映射到统一的编号空间
- **防止 Hart ID 越界：** 限制 Hart ID 范围，确保索引在有效范围内
- **简化多核调度：** 在启动阶段使用标准化的 Hart ID，简化后续初始化逻辑

---

### 2. OP-TEE 安全监控优化

#### 修改文件
- `lib/sbi/optee/pmp.c`
- `lib/sbi/optee/pmp.h`
- `lib/sbi/optee/sm.c`
- `lib/sbi/optee/sm.h`

#### 实际作用

**2.1 函数重命名：pmp_set_permission → pmp_set_keystone**

**修改内容：**
```c
// 修改前
int pmp_set_permission(int region_idx, uint8_t perm)

// 修改后  
int pmp_set_keystone(int region_idx, uint8_t perm)
```

**实际意义：**
- **语义明确化：** 新名称 `pmp_set_keystone` 更准确地反映了这是为 Keystone（一个 RISC-V 安全执行环境框架）设置 PMP 权限
- **避免混淆：** 与通用的 PMP 设置函数区分开，表明这是特定于安全监控的实现
- **代码可读性：** 其他开发者更容易理解这是安全相关的配置函数

**2.2 Mailbox 配置方式改进**

**修改前：**
```c
int mailboxm_init()
{
    int nodeoffset, rc;
    uint64_t reg_addr, reg_size;
    void *fdt = fdt_get_address();

    // 从设备树中解析 Mailbox 地址
    nodeoffset = fdt_node_offset_by_compatible(fdt, -1, "nuclei,nuclei-mbox");
    if (nodeoffset < 0)
        return -1;
    rc = fdt_get_node_addr_size(fdt, nodeoffset, 0, &reg_addr, &reg_size);
    // ... 验证和初始化
}
```

**修改后：**
```c
#define OPTEE_MAILBOX_BASE		0x8800000
#define OPTEE_MAILBOX_SIZE		0x4000

int mailboxm_init()
{
    int region = -1;
    // 直接使用硬编码地址
    int ret = pmp_region_init_atomic(OPTEE_MAILBOX_BASE, OPTEE_MAILBOX_SIZE,
					 PMP_PRI_ANY, &region, 0);
    if (ret)
        return -1;

    return region;
}
```

**实际意义：**
- **简化配置：** 不再依赖设备树解析，直接使用预定义的地址，减少了启动时的解析开销
- **提高可靠性：** 避免了设备树解析失败导致的初始化失败
- **明确地址空间：** 硬编码地址使内存布局更加清晰，便于维护
- **加速启动：** 减少了启动时的 FDT 解析时间

**2.3 错误处理增强**

**修改前：**
```c
os_region_id = osm_init();
if (os_region_id < 0) {
    sbi_printf("[SM] failed to create reeos pmp entry.\n");
    sbi_hart_hang();
}
```

**修改后：**
```c
os_region_id = osm_init();
if (os_region_id < 0) {
    sbi_printf("[SM] intolerable error - failed to initialize OS memory");
    sbi_hart_hang();
}

// 新增 Mailbox 错误检查
mailbox_region_id = mailboxm_init();
if (mailbox_region_id < 0) {
    sbi_printf("[SM] intolerable error - failed to initialize Mailbox memory");
    sbi_hart_hang();
}
```

**实际意义：**
- **错误严重性明确：** 使用 "intolerable error" 明确标识这些错误是不可容忍的，系统无法继续运行
- **增加 Mailbox 检查：** 新增对 Mailbox 初始化失败的检查，确保所有关键内存区域都正确配置
- **调试友好：** 更详细的错误信息帮助开发者快速定位问题
- **安全性提升：** 确保所有安全关键区域都正确初始化，否则系统挂起

**2.4 代码清理**

**移除的内容：**
- 删除了不必要的 `#include <sbi_utils/fdt/fdt_helper.h>`
- 删除了未使用的外部函数声明
- 清理了注释中的过时信息

**实际意义：**
- **减少依赖：** 减少了对设备树解析模块的依赖
- **代码简洁：** 移除了未使用的代码，提高了可读性
- **编译优化：** 减少了不必要的头文件包含

---

### 3. 调试信息增强

#### 修改文件
- `lib/sbi/sbi_init.c`

#### 实际作用

**修改内容：**
```c
// 冷启动调试信息
static void __noreturn init_coldboot(struct sbi_scratch *scratch, u32 hartid)
{
    // ...
    sbi_boot_print_banner(scratch);
    
    // 新增调试打印
    sbi_printf("init_coldboot:hartid %d\n", hartid);
    // ...
}

// 热启动调试信息
static void __noreturn init_warmboot(struct sbi_scratch *scratch, u32 hartid)
{
    // ...
    sbi_printf("init_warmboot:hartid %d\n", hartid);
    // ...
}
```

**实际意义：**
- **启动流程跟踪：** 开发者可以清楚地看到每个 Hart 的启动路径（冷启动 vs 热启动）
- **多核调试：** 在多核系统中，可以跟踪哪个 Hart 在哪个阶段执行
- **问题定位：** 当系统启动失败时，可以通过串口输出确定故障发生的位置
- **性能分析：** 可以帮助分析启动时间和各阶段的耗时

---

### 4. Nuclei 平台特定配置

#### 修改文件
- `platform/generic/nuclei/customsoc.c`
- `platform/generic/nuclei/evalsoc.c`

#### 实际作用

**4.1 CustomSoC 的 Mailbox 内存属性配置**

**修改内容：**
```c
static int nuclei_customsoc_final_init(bool cold_boot, const struct fdt_match *match)
{
    // ...
    
    /* config host mailbox region to noncachable */
    #define MATTRI0_MASK    0x7F4
    #define MATTRI0_BASE    0x7F3
    #define HOST_MAILBOX_BASE_ADDR  (0x8800000UL)
    #define HOST_MAILBOX_SIZE       (0x4000ULL)

    uint64_t base_val;

    base_val = (HOST_MAILBOX_BASE_ADDR & (~(HOST_MAILBOX_SIZE-1))) | BIT(2) | BIT(0);
    csr_write(MATTRI0_BASE, base_val);
    csr_write(MATTRI0_MASK, ~(HOST_MAILBOX_SIZE-1));
    
    // ...
}
```

**实际意义：**
- **内存属性配置：** 配置 Mailbox 内存区域为 Non-cacheable，确保 Host 和 TEE 之间的通信数据一致性
- **硬件寄存器操作：**
  - `MATTRI0_BASE` (0x7F3)：设置内存区域的起始地址和属性
  - `MATTRI0_MASK` (0x7F4)：设置内存区域的大小掩码
- **位域设置：**
  - `BIT(0)`：使能该内存区域
  - `BIT(2)`：设置为 Non-cacheable 属性
- **地址对齐：** 确保 Mailbox 地址按照其大小对齐（0x8800000 按 0x4000 对齐）

**4.2 EvalSoC 的代码结构调整**

**修改内容：**
```c
static int nuclei_evalsoc_final_init(bool cold_boot, const struct fdt_match *match)
{
    // 变量声明移后
    
    if (!cold_boot) { 
        // 热启动处理（保持不变）
        return 0;
    }

    // 新增的 Mailbox 配置（被条件编译包裹）
    #if 0
    // Mailbox 内存属性配置代码
    #endif   

    sm_init(cold_boot);
    // ...

    // SMP 和缓存配置被包裹在条件编译中
    #if 1
    unsigned long smpcc_base = 0, smpcc_cfg;
    // SMP 和 L2 缓存配置代码
    #endif

    return 0;
}
```

**实际意义：**
- **条件编译控制：** 使用 `#if 0` 和 `#if 1` 包裹可选代码，便于开关特定功能
- **代码组织：** 将相关代码分组，提高可读性
- **可配置性：** 可以根据不同的 SoC 配置启用/禁用特定功能
- **调试便利：** 便于在开发和调试阶段快速开关特定功能

---

## 修改的整体影响

### 安全性提升
1. **PMP 配置更可靠：** 硬编码地址避免了设备树解析的不确定性
2. **错误检查更严格：** 所有关键内存区域的初始化都有严格的错误检查
3. **内存属性正确配置：** Mailbox 区域配置为 Non-cacheable，避免缓存一致性问题

### 可维护性改进
1. **函数命名更清晰：** `pmp_set_keystone` 比 `pmp_set_permission` 更能表达用途
2. **代码结构优化：** 条件编译使代码组织更清晰
3. **调试信息完善：** 启动流程中的调试打印便于问题定位

### 功能性增强
1. **支持复杂 Hart ID 映射：** 掩码机制支持 TEE/REE 双系统架构
2. **启动性能优化：** 减少设备树解析，加速启动过程
3. **平台特定优化：** 针对 Nuclei 平台的特定优化

---

## 潜在风险与注意事项

### 1. Hart ID 掩码限制
- **风险：** 使用 0x3 掩码意味着系统最多支持 4 个 Hart（0-3）
- **注意：** 如果系统超过 4 个 Hart，需要修改掩码值

### 2. 硬编码地址
- **风险：** Mailbox 地址硬编码为 0x8800000，如果硬件变更需要修改代码
- **注意：** 确保该地址与硬件设计一致

### 3. 调试信息
- **风险：** 调试打印会略微增加启动时间
- **注意：** 在生产环境中可以考虑关闭调试输出

---

## 测试建议

1. **多核启动测试：** 验证所有 Hart 的冷启动和热启动都正常工作
2. **Mailbox 通信测试：** 验证 Host 和 TEE 通过 Mailbox 的通信正常
3. **内存属性验证：** 验证 Mailbox 区域的 Non-cacheable 属性正确设置
4. **错误处理测试：** 模拟初始化失败，验证系统正确挂起并输出错误信息

---

## 总结

本次修改针对 Nuclei 平台的 TEE/REE 双系统架构进行了优化，主要包括：

1. **Hart ID 掩码机制** - 支持多核环境下的 Hart ID 映射
2. **OP-TEE 安全监控优化** - 提升代码可读性和可靠性
3. **调试增强** - 便于启动流程跟踪和问题定位
4. **平台特定配置** - 针对 Nuclei 硬件的优化配置

这些修改提升了系统的安全性、可维护性和功能性，特别适合安全关键应用场景。
