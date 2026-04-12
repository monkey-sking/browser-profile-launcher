# Browser Profile Launcher

一个 macOS 小工具，用来把本机上的 Chrome / Edge 浏览器配置列出来，并支持直接启动、扫描非默认目录、删除重复配置。

A small macOS utility that lists local Chrome / Edge browser profiles and lets you launch them directly, scan non-default directories, and remove duplicate configs.

## 支持范围 | Supported Browsers

- Chrome
- Edge

## 功能 | Features

- 自动读取本机默认浏览器配置
- 列出每个 Profile，并直接启动
- 支持搜索配置
- 支持最近使用置顶
- 支持扫描非默认目录
- 支持手动指定配置目录解析
- 支持删除重复配置
- 扫描到的非默认目录会持久化保存，下次打开仍然可见

- Automatically reads default browser profile directories on this Mac
- Lists each profile and launches it directly
- Supports profile search
- Supports recently used profiles
- Supports scanning non-default directories
- Supports manually parsing a specific profile directory
- Supports removing duplicate configs
- Remembers discovered non-default directories between launches

## 识别规则 | Discovery Rules

应用会优先读取默认目录：

The app reads the default directories first:

- `~/Library/Application Support/Google/Chrome`
- `~/Library/Application Support/Microsoft Edge`

点击“扫描非默认目录”后，还会额外扫描常见位置，例如：

When you click `扫描非默认目录`, it also scans common locations such as:

- `~/Library/Application Support`
- `/Volumes` 下各个真实磁盘卷
- Real mounted volumes under `/Volumes`

只要目录中包含 `Local State`，并且能识别为 Chrome / Edge 的用户数据目录，就会被加入列表。

Any directory that contains `Local State` and can be identified as a Chrome / Edge user data directory will be added to the list.

如果你的配置放在更特殊的位置，推荐直接使用“解析目录”手动加入，而不是依赖自动扫描。

If your profiles live in a more unusual location, it is better to add them with `解析目录` instead of relying on automatic scanning.

## 删除规则 | Delete Rules

删除操作不会直接永久删除，而是移到废纸篓。

Delete operations do not permanently erase data. They move the target to Trash.

- 如果是单独的一整套非默认 `user-data` 目录，会把整套目录移到废纸篓
- 如果是默认浏览器根目录下的附加 Profile，会把对应的 Profile 子目录移到废纸篓
- 默认浏览器根目录的 `Default` 配置不允许直接删除

- If the target is a standalone non-default `user-data` directory, the whole directory is moved to Trash
- If the target is an extra profile inside the default browser root, only that profile subdirectory is moved to Trash
- The `Default` profile inside the default browser root cannot be deleted directly

## 运行 | Run

要求：

Requirements:

- macOS 13+
- Swift 6.3+

启动开发版：

Run the development version:

```bash
swift run
```

## 打包成 `.app` | Package as `.app`

执行：

Run:

```bash
./scripts/package_dev_app.sh
```

打包结果会出现在：

The packaged app will be created at:

```bash
dist/BrowserProfileLauncher.app
```

说明：

Notes:

- 这是本地开发版 `.app`
- 当前未做代码签名和公证
- 首次打开可能需要在 macOS 里右键选择“打开”

- This is a local development `.app`
- It is not code signed or notarized yet
- On first launch, macOS may require you to right-click and choose `Open`

## 测试 | Test

```bash
swift test
```

## 项目结构 | Project Structure

```text
.
├── Package.swift
├── README.md
├── Sources/
│   └── browser-profile-launcher/
│       └── browser_profile_launcher.swift
├── Tests/
│   └── browser-profile-launcherTests/
│       └── browser_profile_launcherTests.swift
└── scripts/
    └── package_dev_app.sh
```

## 当前边界 | Current Scope

- 目前只支持 Chrome / Edge
- 目前删除能力只针对本地配置目录，不处理浏览器账号侧同步数据
- 目前没有做代码签名、公证、安装器或 DMG 分发

- Only Chrome / Edge are supported for now
- Deletion only targets local profile directories and does not manage synced browser account data
- Code signing, notarization, installers, and DMG distribution are not included yet
