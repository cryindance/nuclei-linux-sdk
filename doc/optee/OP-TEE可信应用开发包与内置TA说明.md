# OP-TEE 可信应用开发包与内置 TA 说明

## 一、概述

本文档总结了 Nuclei Linux SDK 中集成的 OP-TEE 可信执行环境下，可信应用（Trusted Application，TA）相关的核心概念与机制，包括：

- `ta_dev_kit.mk` 的作用与导出包位置
- **PTA**、In-tree TA 与 Out-of-tree TA 的区别与对比
- `avb` TA 的性质与功能
- `trusted_keys` TA 的功能与实现原理
- HUK（Hardware Unique Key）密钥派生机制的设计目的

---

## 二、TA 开发包（ta_dev_kit）

### 2.1 ta_dev_kit.mk 的作用

`ta_dev_kit.mk` 是 OP-TEE 为**外部（out-of-tree）**可信应用提供的核心构建 Makefile。它的目标是让没有 `optee_os` 完整源码的外部项目，也能编译出符合规范的 `.ta` 文件。

外部 TA 的 Makefile 通常这样引用它：

```makefile
BINARY = 8aaaf200-2450-11e4-abe2-0002a5d5c51b
-include $(TA_DEV_KIT_DIR)/mk/ta_dev_kit.mk
```

`ta_dev_kit.mk` 内部自动完成了以下工作：

| 功能 | 说明 |
|------|------|
| 编译器配置 | 加载 `conf.mk` 和具体的编译器规则（`gcc.mk`/`clang.mk`） |
| 编译标志 | 自动添加头文件搜索路径（`-I$(TA_DEV_KIT_DIR)/include`）、日志级别宏等 |
| 标准库链接 | 自动链接 `libutils.a`、`libutee.a`、`libdl.a`（可选 `libmbedtls.a`） |
| 构建规则 | 引入 `compile.mk`、`link.mk` 等，外部 TA 只需提供 `srcs` 和 `BINARY`（UUID）即可 |

### 2.2 导出包位置

在 Nuclei Linux SDK 项目中，`optee_os` 编译完成后，TA 开发包被导出到以下目录：

```bash
/home/jingo/work/nuclei-linux-sdk/work/evalsoc/optee/optee_os/export-ta_rv64
```

该路径由项目根目录 `Makefile` 中 `O=$(optee_os_wrkdir)` 指定。

导出包内部结构如下：

```
export-ta_rv64/
├── mk/                    # Makefile 规则
│   ├── ta_dev_kit.mk
│   ├── conf.mk
│   ├── compile.mk
│   └── ...
├── lib/                   # 预编译的 TA 静态库
│   ├── libutils.a
│   ├── libutee.a
│   ├── libdl.a
│   └── libmbedtls.a
├── include/               # TA 端头文件
├── host_include/          # Host（REE）端头文件
├── src/                   # 启动代码与链接脚本
├── scripts/               # 签名脚本
├── keys/                  # 默认签名私钥
└── ta/                    # 预编译的内置 TA 二进制
    ├── 023f8f1a-292a-432b-8fc4-de8471358067.ta   # avb
    ├── f04a0fe7-1f5d-4b9b-abf7-619b85b4ce8c.ta   # trusted_keys
    └── fd02c9da-306c-48c7-a49c-bbd827ae86ee.ta   # pkcs11
```

---

## 三、PTA、In-tree TA 与 Out-of-tree TA 的对比

在 OP-TEE 中，安全应用分为三种形态：**PTA（Pseudo TA，伪可信应用）**、**In-tree User TA** 和 **Out-of-tree User TA**。它们的本质区别体现在**运行态、编译方式和源码位置**上。

### 3.1 三种 TA 的核心差异

| 维度 | PTA | In-tree TA | Out-of-tree TA |
|------|-----|------------|----------------|
| **源码位置** | `optee_os/core/pta/` | `optee_os/ta/` 目录内部 | `optee_os` 仓库外部 |
| **运行态** | **内核态**（与 TEE Core 同一地址空间） | **用户态**（独立进程/沙箱） | **用户态**（独立进程/沙箱） |
| **编译产物** | 链接进 `tee.elf`，**无独立 `.ta` 文件** | 独立的 `.ta` 二进制文件 | 独立的 `.ta` 二进制文件 |
| **API 层级** | 可直接调用 TEE Core 内部 API | 通过 `libutee` 调用系统服务 | 通过 `libutee` 调用系统服务 |
| **内存隔离** | **无**（与内核同权限） | **有**（运行在独立虚拟地址空间） | **有**（运行在独立虚拟地址空间） |
| **典型代表** | `PTA_SYSTEM`、`PTA_DEVICE` | `avb`、`pkcs11`、`trusted_keys` | `hello_world`、`optee_test` 中的 26 个测试 TA |
| **Early TA 支持** | 不适用（本身就是内核一部分） | **可以**（嵌入 TEE Core ELF） | **不能** |
| **谁可以访问** | 所有 TA 和 REE 客户端（取决于实现） | 普通 REE 客户端 | 普通 REE 客户端 |

### 3.2 形象比喻

可以将三者的关系类比为操作系统的不同组件：

- **PTA** ≈ **内核模块 / 系统调用**：跟 TEE Core 跑在一起，权限最大，没有独立进程隔离。它存在的目的是为 TEE 内部或外部提供某些需要特权的服务（如 HUK 派生、设备操作、调试功能）。
- **In-tree TA** ≈ **系统预装应用**：源码在 `optee_os` 仓库里，跟 TEE Core 一起编译发布，但运行时是独立的用户态进程（`.ta` 文件）。
- **Out-of-tree TA** ≈ **第三方应用**：源码在外部仓库，开发者用 `ta_dev_kit` 编译，运行在同样的沙箱里，与 In-tree TA 权限平等。

### 3.3 为什么需要 PTA

有些操作是 User TA **无论如何都无法完成的**，例如：

- 读取芯片的 **Hardware Unique Key（HUK）**
- 直接操作安全外设（如密码学加速器、安全存储控制器）
- 在 TEE Core 启动早期就提供服务（此时文件系统还不存在）

这些场景下，PTA 作为"内核态服务"是唯一选择。比如 `trusted_keys` TA 需要密封密钥时，必须通过 `PTA_SYSTEM` 调用 `PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY`，因为 User TA 没有权限直接接触 HUK。

### 3.4 In-tree TA 与 Out-of-tree TA 的进一步区别

从**运行时权限**和**安全隔离**的角度，In-tree TA 与 Out-of-tree TA **没有区别**——它们都是 User TA，运行在相同的沙箱中，使用相同的 `libutee` API。

主要差异在于**源码归属、编译方式和分发方式**：

| 维度 | In-tree TA | Out-of-tree TA |
|------|------------|----------------|
| **源码位置** | `optee_os/ta/` 目录内部 | `optee_os` 仓库外部（如 `optee_examples`、`optee_test`） |
| **编译入口** | `optee_os/ta/mk/build-user-ta.mk` | 外部 Makefile 通过 `ta_dev_kit.mk` 编译 |
| **编译产物** | 输出到 `optee_os` 构建目录，同时复制到 `export-ta_rv64/ta/` | 输出到外部项目自身目录 |
| **Early TA 支持** | **可以**成为 Early TA（嵌入 TEE Core ELF） | **不能**成为 Early TA |

### 3.5 内置 TA 列表

`optee_os` 内置的 In-tree User TA 包括：

- `avb`（Android Verified Boot）
- `pkcs11`（PKCS#11 加密令牌接口）
- `trusted_keys`（Linux Trusted Keys 的 TEE 后端）

### 3.6 关于 Early TA

Early TA 是一种在 TEE Core 启动初期就被加载到内存中的 TA，不需要依赖文件系统。它通过将 `.ta` 二进制直接嵌入 TEE Core ELF 实现。

在 ARM 平台上，可通过 `CFG_IN_TREE_EARLY_TAS` 启用：

```makefile
CFG_IN_TREE_EARLY_TAS += avb/023f8f1a-292a-432b-8fc4-de8471358067
```

但在**芯来（nuclei）RISC-V 平台**上，该特性被显式关闭：

```makefile
# core/arch/riscv/plat-nuclei/conf.mk
$(call force,CFG_EARLY_TA,n)
$(call force,CFG_EARLY_TA_COMPRESS,n)
```

因此，在当前项目中，所有 In-tree TA 与普通 Out-of-tree TA 一样，最终都需要通过文件系统在运行时加载。

---

## 四、avb TA

### 4.1 基本性质

- **UUID**：`023f8f1a-292a-432b-8fc4-de8471358067`
- **类型**：In-tree **User TA**（不是 PTA）
- **源码位置**：`optee/optee_os/ta/avb/`

它编译后生成独立的 `.ta` 文件，通过 `libutee` 调用 TEE 系统服务。

### 4.2 功能

`avb` TA 是 **Android Verified Boot（AVB）** 的安全状态管理器，负责保管启动验证链中的关键状态数据。它暴露的命令包括：

```c
TA_AVB_CMD_READ_ROLLBACK_INDEX     // 读回滚索引
TA_AVB_CMD_WRITE_ROLLBACK_INDEX    // 写回滚索引
TA_AVB_CMD_READ_LOCK_STATE         // 读设备锁状态
TA_AVB_CMD_WRITE_LOCK_STATE        // 写设备锁状态
TA_AVB_CMD_READ_PERSIST_VALUE      // 读持久化值
TA_AVB_CMD_WRITE_PERSIST_VALUE     // 写持久化值
```

所有数据均存储在 **RPMB（Replay Protected Memory Block）** 中：

```c
static const uint32_t storageid = TEE_STORAGE_PRIVATE_RPMB;
```

这确保了普通世界（Normal World）无法直接篡改这些启动状态。

---

## 五、trusted_keys TA

### 5.1 基本性质

- **UUID**：`f04a0fe7-1f5d-4b9b-abf7-619b85b4ce8c`
- **类型**：In-tree **User TA**
- **源码位置**：`optee/optee_os/ta/trusted_keys/`
- **Linux 对应配置**：`CONFIG_TRUSTED_KEYS_TEE=y`

### 5.2 功能

`trusted_keys` TA 是 Linux 内核 **Trusted Keys** 子系统的 TEE 后端，核心作用是：

> 利用芯片的**硬件唯一密钥（HUK）**对用户密钥进行**密封（Seal）**和**解封（Unseal）**，确保密钥只能在该设备上被恢复。

暴露的 3 个命令：

| 命令 | 值 | 作用 |
|------|-----|------|
| `TA_CMD_GET_RANDOM` | `0x0` | 生成随机数 |
| `TA_CMD_SEAL` | `0x1` | 用 HUK 派生密钥加密明文密钥 |
| `TA_CMD_UNSEAL` | `0x2` | 用 HUK 派生密钥解密密封数据块 |

### 5.3 访问控制

在 `TA_OpenSessionEntryPoint` 中，该 TA 严格限制只有 Linux 内核才能访问：

```c
if (id.login != TEE_LOGIN_REE_KERNEL)
    res = TEE_ERROR_ACCESS_DENIED;
```

普通用户态应用无法直接与其建立会话。

### 5.4 加密实现

- **算法**：AES-256-GCM
- **数据格式**：`struct tk_blob_hdr`（包含 `reserved` + 16 字节 IV + 16 字节 TAG + 密文）

---

## 六、HUK 密钥派生机制

### 6.1 派生流程

`trusted_keys` TA 并不直接使用裸 HUK 加密，而是通过调用系统 PTA 的 `PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY` 命令，由 `huk_subkey_derive()` 派生出一个子密钥：

```c
huk_subkey_derive(HUK_SUBKEY_UNIQUE_TA, data, data_len, subkey, subkey_len);
```

其中 `data` 的构成为：

```c
memcpy(data, &uctx->ts_ctx->uuid, sizeof(TEE_UUID));           // 调用者 TA 的 UUID
memcpy(data + sizeof(TEE_UUID), extra_data, extra_data_len);   // 可选额外数据
```

`huk_subkey_derive()` 内部使用 **HMAC-SHA256**：

```c
crypto_mac_init(ctx, huk.data, sizeof(huk.data));    // 以 HUK 为密钥
mac_usage(ctx, usage);                                // 混入用途标识（如 HUK_SUBKEY_UNIQUE_TA）
crypto_mac_update(ctx, data, data_len);               // 混入 UUID + extra_data
crypto_mac_final(ctx, subkey, subkey_len);            // 输出子密钥
```

### 6.2 为什么不用裸 HUK

派生子密钥的**主要目的不是"增加 HUK 安全性"**（HUK 本身就在 TEE Core 内部，TA 根本接触不到），而是实现**隔离**：

1. **用途隔离**：RPMB、SSK、TA 专属密钥等不同场景使用不同的 `usage` 标识，生成互不相关的子密钥。
2. **TA 隔离**：不同 TA 的 UUID 不同，即使都调用同一个 PTA 接口，派生出的密钥也不同。例如 `pkcs11` TA 无法解封 `trusted_keys` TA 的数据。
3. **场景隔离**：通过 `extra_data`，同一 TA 内部还可以为不同用途（如磁盘加密 vs IMA）派生不同密钥。

这是一种标准的**密钥分层**设计，确保一把 HUK 能够安全地服务于多个租户和多个场景。

---

## 七、总结

| 对象 | 类型 | 核心作用 |
|------|------|----------|
| `ta_dev_kit.mk` | 构建脚本 | 为外部 TA 提供编译、链接、库依赖的"脚手架" |
| **PTA**（如 `PTA_SYSTEM`） | 伪可信应用（内核态） | 提供 User TA 无法完成的特权服务（如 HUK 派生、设备访问） |
| `avb` | In-tree User TA | Android 启动验证的安全状态管理（回滚索引、锁状态等） |
| `trusted_keys` | In-tree User TA | 为 Linux Trusted Keys 提供基于 HUK 的密钥密封/解封服务 |
| `huk_subkey_derive` | 核心安全机制 | 基于 HUK 派生隔离子密钥，实现用途/TA/场景三重隔离 |

在当前 Nuclei RISC-V 平台上，由于 `CFG_EARLY_TA=n`，所有 In-tree TA 均以普通 `.ta` 文件形式存在，最终需通过文件系统加载运行。
