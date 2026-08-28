---
name: "harmonyos-build-install"
description: "Builds the AHUTong HarmonyOS app with hvigorw and installs+launches it on a connected device via hdc. Invoke when user asks to 构建/打包/编译/安装/部署/重新安装 the app, or wants the build+install flow run."
---

# HarmonyOS 构建 + 真机安装启动

在 Windows 上把本项目（AHUTong-HarmonyOS-migration-android-to-harmonyos）构建成 debug HAP 并安装到已连接的真机/模拟器、启动应用的最简流程。

## 前置约定（已验证）

- DevEco Studio 安装目录：`C:\Program Files\Huawei\DevEco Studio`
- SDK：`C:\Program Files\Huawei\DevEco Studio\sdk\default`（项目 `local.properties` 里的 `sdk.dir`）
- 构建工具：`<DevEco>\tools\hvigor\bin\hvigorw.bat`
- 设备工具：`<DevEco>\sdk\default\openharmony\toolchains\hdc.exe`
- 包名：`com.openahu.ahutong`（见 `AppScope/app.json5` 的 `bundleName`）
- 入口 Ability：`EntryAbility`（见 `entry/src/main/module.json5`）

> 若工具路径找不到，用 `Get-ChildItem "C:\Program Files\Huawei\DevEco Studio" -Recurse -Filter "hvigorw.bat"` / `-Filter "hdc.exe"` 重新定位。包名/Ability 变更时从 app.json5 / module.json5 读取。

## 1. 构建（关键坑：必须先设 DEVECO_SDK_HOME）

不设置会报 `hvigor ERROR: Invalid value of 'DEVECO_SDK_HOME'`。在 PowerShell 中必须与构建命令在**同一个命令会话**里设置环境变量（shell 状态不跨命令保留）：

```powershell
$env:DEVECO_SDK_HOME = "C:\Program Files\Huawei\DevEco Studio\sdk\default"
& "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

- 必须在项目根目录执行（用 `cwd` 参数指定）。
- 成功标志：`hvigor BUILD SUCCESSFUL`。
- 产物：`entry\build\default\outputs\debug\entry-debug-signed.hap`
- 预期耗时约 40-60 秒；命令可能很长，建议设 10 分钟超时或后台运行。

## 2. 安装到设备

```powershell
# 确认设备在线（输出一行设备序列号即正常）
& "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe" list targets

# 覆盖安装
& "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe" install -r "C:\Users\InChange_Jiang\Documents\HarmonyProjects\AHUTong-HarmonyOS-migration-android-to-harmonyos\entry\build\default\outputs\debug\entry-debug-signed.hap"
```

- 成功标志：`install bundle successfully.`
- `-r` 表示覆盖已安装的同包名应用。

## 3. 启动应用

```powershell
& "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe" shell aa start -a EntryAbility -b com.openahu.ahutong
```

- 成功标志：`start ability successfully.`

## 4. 验证与排障

- 需要登录的页面（课表/成绩等）只能由用户在真机上操作验证；可让用户操作后，用 `hdc shell hilog` 按标签 `AHUTong` 抓日志辅助确认。
- 若 `list targets` 为空：设备未连接或未开启 HDC（设置里开启"USB 调试/无线调试"），需先让用户连接。
- 构建只改业务代码时无需清理；若出现旧产物残留导致的诡异问题，可 `hdc uninstall com.openahu.ahutong` 后重装。

## 5. 注意

- 本 skill 只封装构建/安装/启动机制，不含任何登录凭证、学号或抓取数据。
- 语言遵循用户当前对话语言。
