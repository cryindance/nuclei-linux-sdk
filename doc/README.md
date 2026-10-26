# Nuclei Linux SDK 文档索引

本目录集中存放 Nuclei Linux SDK 相关的分析、设计、调试与操作文档。
代码仓库根目录只保留 `README.md`（上游说明）与本索引。

## 一、按主题导航

### 1. HSM 与安全启动
| 文档 | 说明 |
|------|------|
| [Nuclei_HSM_Secure_Boot.md](hsm/Nuclei_HSM_Secure_Boot.md) | HSM 安全启动流程与实现说明 |
| [conf修改分析.md](hsm/conf修改分析.md) | `conf/evalsoc` 下构建脚本与配置为支持 HSM 安全启动所做的全部修改分析（含变更总览图） |

### 2. OP-TEE
| 文档 | 说明 |
|------|------|
| [PROJECT_ANALYSIS.md](optee/PROJECT_ANALYSIS.md) | OP-TEE RISC-V 项目整体分析（目录结构、组件关系、构建链路） |
| [OP-TEE可信应用开发包与内置TA说明.md](optee/OP-TEE可信应用开发包与内置TA说明.md) | TA 开发包结构、内置 TA 列表，以及基于 HUK 的密钥密封/解封机制 |
| [OP-TEE密钥体系说明.md](optee/OP-TEE密钥体系说明.md) | OP-TEE 密钥层级（HUK / SSK / TA 密钥）与派生关系，含密钥层级图 |
| [OP-TEE编译问题修复报告.md](optee/OP-TEE编译问题修复报告.md) | 编译报错的原因分析与修复记录（含 `ta_dev_kit.mk` 同步修复） |
| [代码修改总结报告.md](optee/代码修改总结报告.md) | OP-TEE RISC-V 项目代码修改汇总、详细分析与影响评估 |
| [提交代码详细分析.md](optee/提交代码详细分析.md) | OP-TEE OS 提交逐条分析：变更细节与提交间关联关系 |

### 3. OpenSBI
| 文档 | 说明 |
|------|------|
| [OpenSBI学习与开发文档.md](opensbi/OpenSBI学习与开发文档.md) | OpenSBI 架构、启动流程与开发入门 |
| [opensbi代码修改说明.md](opensbi/opensbi代码修改说明.md) | 本 SDK 对 OpenSBI 的具体改动说明 |

### 4. 密码学接口
| 文档 | 说明 |
|------|------|
| [nuclei_linux密码学接口.md](crypto/nuclei_linux密码学接口.md) | 基于 HSM + Mailbox 的硬件加解密/哈希接口说明 |
| [nuclei_crypto_full_arch.svg](crypto/nuclei_crypto_full_arch.svg) | 完整密码学调用架构图（源文件 `.dot` 同目录） |
| [crypto_arch.svg](crypto/crypto_arch.svg) | 早期密码学架构图（源文件 `.dot` 同目录） |

### 5. 构建流程
| 文档 | 说明 |
|------|------|
| [make freeloader的构建顺序.md](build/make%20freeloader的构建顺序.md) | freeloader 的构建依赖与执行顺序（含依赖关系图） |

### 6. Patch 分析
| 文档 | 说明 |
|------|------|
| [Patch文件对比分析报告.md](patch/Patch文件对比分析报告.md) | SDK patch 文件与上游的逐文件对比分析（含 patch 结构与对比图） |

### 7. U-Boot
| 文档 | 说明 |
|------|------|
| [uboot修改分析.md](uboot/uboot修改分析.md) | U-Boot Nuclei HSM 分支（dev_hsm）6 个提交的逐项修改分析：RISC-V 启动层、板级初始化、Mailbox HSM 驱动 |

### 8. 图片与图表（无对应独立文档）
| 目录 | 说明 |
|------|------|
| [misc/Apollo11_P63_images/](misc/Apollo11_P63_images/) | Apollo11 P63 平台流程图 |
| [misc/DETAILED_DESIGN_images/](misc/DETAILED_DESIGN_images/) | TFLM + FreeRTOS 架构图（原设计文档不在本仓库） |
| [misc/freeloader_composition_images/](misc/freeloader_composition_images/) | freeloader 组成与构建依赖图 |

## 二、阅读顺序建议

| 目标 | 建议顺序 |
|------|---------|
| 第一次接触本项目 | 根目录 `README.md` → `optee/PROJECT_ANALYSIS.md` → `opensbi/OpenSBI学习与开发文档.md` → `build/make freeloader的构建顺序.md` |
| 做安全启动相关开发 | `hsm/Nuclei_HSM_Secure_Boot.md` → `hsm/conf修改分析.md` → `optee/OP-TEE密钥体系说明.md` |
| 排查密码学调用 | `crypto/nuclei_linux密码学接口.md` → `crypto/nuclei_crypto_full_arch.svg` |
| 对照上游改动 | `patch/Patch文件对比分析报告.md` |

## 三、文档维护约定

1. **新增文档按主题放入对应子目录**（`hsm/`、`optee/`、`opensbi/`、`uboot/`、`crypto/`、`build/`、`patch/`、`misc/`）
2. **图片目录命名为 `{文档名}_images/`**，与文档放在同一目录，引用使用相对路径
3. 图表使用 Graphviz DOT 生成 SVG，**保留 `.dot` 源文件**
4. 新增或重命名文档后，**同步更新本索引**
5. 本目录内容的备份同步到 `~/work/doc`，并在生成工作日报时推送到 GitHub 私有仓库 `work-doc`
