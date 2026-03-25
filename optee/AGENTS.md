# OP-TEE RISC-V 项目知识库

**项目**: 芯来科技(Nuclei) RISC-V 架构 OP-TEE 可信执行环境
**架构**: RISC-V RV64IMAFDC (64位), 支持最多8核SMP
**语言**: C (~95%), Python构建脚本 (~4%), C++测试 (~1%)
**代码量**: 3203文件, 2589 C源文件, 71 Makefile + 348 .mk
**标准**: GlobalPlatform TEE 标准兼容

---

## 项目结构

```
optee/
├── optee_os/              # TEE安全操作系统核心 (~1800文件)
│   ├── core/arch/riscv/   # RISC-V架构代码
│   │   ├── plat-nuclei/   # 芯来平台实现(主要工作区)
│   │   ├── kernel/        # 线程、中断、启动
│   │   ├── mm/            # 内存管理(MMU/PMP)
│   │   └── tee/           # 系统调用处理
│   ├── core/drivers/      # 设备驱动
│   ├── ta/                # 内置可信应用
│   └── lib/               # 库(libutee, mbedtls等)
│
├── optee_client/          # 客户端库与工具 (~300文件)
│   ├── libteec/           # TEE客户端API
│   ├── libckteec/         # PKCS#11接口
│   └── tee-supplicant/    # 用户空间守护进程
│
├── optee_examples/        # 示例程序 (~200文件)
│   ├── hello_world/       # 基础示例
│   ├── secure_storage/    # 安全存储
│   ├── aes/acipher/       # 加密示例
│   └── demo/              # 安全中断测试
│
├── optee_test/            # 测试套件 (~700文件)
│   ├── host/xtest/        # 测试主机程序
│   └── ta/                # 测试用TA(26个)
│
└── optee_benchmark/       # 性能测试工具
```

---

## 代码定位指南

| 任务 | 位置 | 关键文件 |
|------|------|----------|
| **添加平台支持** | `optee_os/core/arch/riscv/plat-*/` | `conf.mk`, `main.c`, `platform_config.h` |
| **修改中断处理** | `optee_os/core/arch/riscv/plat-nuclei/` | `main.c` (PLIC处理) |
| **添加系统调用** | `optee_os/core/tee/` | `tee_svc_*.c` |
| **添加驱动** | `optee_os/core/drivers/` | 新建目录 + `sub.mk` |
| **开发TA** | `optee_examples/*/ta/` | `*_ta.c`, `include/*_ta.h` |
| **开发CA** | `optee_examples/*/host/` | `main.c` |
| **修改内存布局** | `optee_os/core/arch/riscv/plat-nuclei/` | `conf.mk` (CFG_TZDRAM_*) |
| **调试日志** | 全局 | `DMSG()`/`IMSG()`/`EMSG()` |

---

## 关键代码地图

### 核心API入口点

| 符号 | 类型 | 文件 | 作用 |
|------|------|------|------|
| `TA_CreateEntryPoint` | 函数 | TA实现 | TA实例创建入口 |
| `TA_OpenSessionEntryPoint` | 函数 | TA实现 | 会话打开入口 |
| `TA_InvokeCommandEntryPoint` | 函数 | TA实现 | 命令处理入口 |
| `TEEC_InitializeContext` | 函数 | `libteec` | CA初始化TEE连接 |
| `TEEC_OpenSession` | 函数 | `libteec` | CA打开TA会话 |
| `TEEC_InvokeCommand` | 函数 | `libteec` | CA调用TA命令 |
| `itr_core_handler` | 函数 | `plat-nuclei/main.c` | PLIC中断处理 |
| `thread_std_smc_entry` | 函数 | `core/arch/riscv/kernel/thread.c` | SMC入口处理 |

### 关键宏定义

| 宏 | 定义位置 | 用途 |
|----|---------|------|
| `TEE_SUCCESS` | `tee_api_types.h` | 成功返回值(0) |
| `TEE_ERROR_*` | `tee_api_types.h` | 错误码定义 |
| `TEE_PARAM_TYPE_*` | `tee_api_types.h` | 参数类型 |
| `DMSG/IMSG/EMSG` | `trace.h` | 调试/信息/错误日志 |
| `CFG_TZDRAM_START` | `conf.mk` | TEE内存起始地址 |
| `CFG_NUM_THREADS` | `conf.mk` | 线程数配置 |

---

## 编码约定

### 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| **函数** | snake_case | `thread_get_exceptions()`, `tee_ta_init_session()` |
| **变量** | 小写简短 | `uint32_t timeout1`, `struct mutex *m` |
| **全局变量** | 模块前缀 | `static struct tpm2_chip *tpm2_device` |
| **类型** | `TEE_`前缀 | `TEE_Result`, `TEE_ObjectHandle` |
| **常量** | 全大写 | `PTA_NUCLEI_SEC_TIMER_CMD_SET_TIMEOUT` |
| **结构体** | 小写 | `struct mutex { ... }` |

### 错误处理模式

```c
// 标准错误处理模式
TEE_Result some_function(uint32_t param_types, TEE_Param params[4])
{
    TEE_Result res = TEE_ERROR_GENERIC;
    void *buffer = NULL;
    
    // 1. 参数检查
    if (exp_param_types != param_types)
        return TEE_ERROR_BAD_PARAMETERS;
    
    // 2. 资源分配并检查
    buffer = TEE_Malloc(size, 0);
    if (!buffer)
        return TEE_ERROR_OUT_OF_MEMORY;
    
    // 3. 执行业务逻辑
    res = do_something(buffer);
    if (res)  // 简写: res != TEE_SUCCESS
        goto out;  // 跳转到统一清理点
    
out:
    // 4. 统一资源释放
    TEE_Free(buffer);
    return res;
}
```

### 日志系统

```c
#include <trace.h>

// 5个级别
MSG(...)     // 始终输出
EMSG(...)    // ERROR (0) - 错误
IMSG(...)    // INFO (1)  - 重要信息  
DMSG(...)    // DEBUG (2) - 调试
FMSG(...)    // FLOW (3)  - 函数流程

// 使用示例
DMSG("Got value: %u from NW", params[0].value.a);
EMSG("Invalid Param types");
```

### 头文件包含顺序

```c
// SPDX-License-Identifier: BSD-2-Clause
/*
 * Copyright 2023 Nuclei System Technology.
 */

// 1. 标准库
#include <assert.h>
#include <string.h>

// 2. TEE API
#include <tee_api.h>
#include <tee_api_types.h>
#include <trace.h>

// 3. 内核头
#include <kernel/thread.h>
#include <mm/core_mmu.h>

// 4. 平台配置
#include <platform_config.h>
```

---

## 反模式与禁忌

### ❌ 禁止的做法

1. **不要使用 `as any` 或类型抑制** - C代码无此概念，但确保类型严格匹配
2. **不要在错误处理中嵌套太深** - 使用 `goto out` 模式
3. **不要忽略资源分配失败** - 所有malloc必须检查返回值
4. **不要直接操作物理地址** - 使用 `core_mmu_get_va()` 映射后再访问
5. **不要在中断处理中使用复杂逻辑** - 保持简短，快速完成
6. **不要修改 `plic_secure_int` 数组** - 通过OpenSBI接口注册安全中断

### ⚠️ 注意事项

1. **PMP条目有限** - 框架需要至少4个条目
2. **PLIC中断路由** - 安全中断和非安全中断需要在系统层面规划
3. **内存对齐** - `mattri_base` 需要以共享区域大小对齐
4. **多核同步** - 使用 `mutex_lock()`/`mutex_unlock()` 保护共享数据
5. **TA开发限制** - 用户TA运行在沙箱中，不能直接访问硬件

---

## 常用命令

```bash
# 构建OP-TEE
make -C optee/optee_os O=out CFG_TEE_CORE_LOG_LEVEL=3

# 构建示例
make -C optee/optee_examples O=out

# 构建客户端
make -C optee/optee_client

# 运行测试
optee_example_hello_world
optee_example_demo

# 调试日志查看
# 通过串口查看OP-TEE日志输出
```

---

## 平台移植要点

### 移植新平台需要修改的文件

1. **`optee_os/core/arch/riscv/plat-<platform>/conf.mk`** - 编译配置
2. **`optee_os/core/arch/riscv/plat-<platform>/platform_config.h`** - 外设地址
3. **`optee_os/core/arch/riscv/plat-<platform>/main.c`** - 平台初始化
4. **`freeloader/freeloader.S`** - 镜像加载地址
5. **opensbi配置** - 平台payload地址

### 关键配置项

```makefile
# conf.mk
CFG_TZDRAM_START ?= 0x41800000    # TEE内存起始
CFG_TZDRAM_SIZE  ?= 0x00800000    # TEE内存大小 (8MB)
CFG_SHMEM_START  ?= 0x41200000    # 共享内存起始
CFG_NUM_THREADS=4                  # 线程数
CFG_TEE_CORE_NB_CORE=8             # CPU核心数
```

---

## 延伸阅读

- **README.md** - 详细使用说明和启动日志
- **README_en.md** - 英文版说明
- **PROJECT_ANALYSIS.md** - 项目详细分析文档
- **optee_riscv_arch.png** - 架构图
- **optee_os/CHANGELOG.md** - 版本变更日志

---

*最后更新: 2026-03-19 | 生成工具: init-deep*
