# MoonTV

MoonTV 是一个面向 Android 平板 / Android TV 的个人观影客户端，提供两条并行的入口。Android 包名仍保留为 `com.moonbox.app`，以便直接覆盖升级已有安装。

- **媒体库模式**：连接自己的 Jellyfin、Emby 或 Plex，像原生客户端一样浏览电影、剧集、季与集，继续观看，并把播放进度写回服务器。
- **片源模式**：聚合 MoonTV / LunaTV `api_site` 与 TVBox `sites` 配置，站源库浏览、全源搜索、选集播放。

> 本项目基于 [Moonfin-Core](https://github.com/Moonfin-Client/Moonfin-Core) 的视觉语言、品牌素材与 GPL-3.0 许可进行独立实现。MoonTV 不提供、不托管任何媒体或直播内容。

## 功能

### 媒体库模式

- Jellyfin / Emby：账号密码登录，自动读取服务器名称与用户信息。
- Plex：使用 `X-Plex-Token` 登录，自动读取 `friendlyName`。
- 电影 / 剧集媒体库切换，海报网格与分页加载。
- 继续观看（Jellyfin/Emby `Items/Resume`，Plex `library/onDeck`）。
- 继续观看卡片长按菜单：继续播放、收藏/取消收藏、隐藏；菜单紧贴卡片弹出，不再从屏幕底部出现。
  - Jellyfin/Emby 的收藏状态同步到服务端；Plex 收藏保存在本机。
  - 隐藏只影响本机继续观看列表，隐藏后不再显示恢复入口。
- 顶部收藏入口：展示媒体服务器中的收藏电影、剧集与单集；Jellyfin/Emby 读取服务端收藏，Plex 读取本机收藏。
- 详情页：简介、年份、分级、时长、类型、季选择与选集。
- 直接播放（Jellyfin/Emby `Videos/{id}/stream`，Plex `library/parts/{id}/stream`）。
- 播放进度上报：
  - Jellyfin/Emby：`Sessions/Playing`、`Sessions/Playing/Progress`、`Sessions/Playing/Stopped`。
  - Plex：`/:/timeline` 的 `playing` / `paused` / `stopped` 状态。
- 进入详情页时可从上次位置继续；播放结束/退出时回写进度。
- 媒体库内容检索统一通过顶部栏搜索完成。

### 片源模式

- 支持 MoonTV / LunaTV 配置中的 `api_site` 映射。
- 支持 TVBox 配置中的 `sites` 数组（JSON `type: 1` 与 XML `type: 0`）。
- 支持 Base58 编码的订阅内容（MoonTV/LunaTV 的 `format=2` / `format=3` 场景）。
- 多配置聚合、站源切换、单个站源启用/禁用与删除、配置刷新与删除。
- 站源库页面按站源浏览，自动提取分类，支持分类筛选与分页加载；顶部直接进入内容，不再显示宣传横幅。
- 顶部栏统一搜索：同时检索媒体库、当前源，或最多 24 个源的全源搜索。
- 详情页展示海报、简介、演职员、线路与选集。
- 内置 `media_kit` / libmpv 播放器，支持 HLS / m3u8、自动下一集、选集与屏幕常亮。

### 共用体验

- 透明顶部栏：左侧 MoonTV 品牌标识、居中图标导航（媒体库、站源库、搜索、收藏、设置）、右侧本地时钟；顶部与页面共用同一渐变背景，同时适配触屏平板与 D-pad 遥控器焦点。
- 媒体库与片源共用播放器、播放列表与返回逻辑。
- 媒体库凭据只保存在本机 SharedPreferences 中。

### 电视与遥控器

- 同一个 APK 同时适配平板和 Android TV。启动时通过 `UiModeManager`、Leanback 与电视硬件特性自动识别电视，不需要安装第二个包。
- 设置 → 电视与遥控器 → 电视模式提供「自动 / 电视优先 / 平板优先」三档；电视盒子误报为平板，或想在平板上预览电视布局时，可手动切换。
- 电视布局会加大顶部栏、卡片、标题与页面留白，焦点卡片/条目会放大并显示高亮描边，移动焦点时自动滚动到可见区域。
- 顶部导航默认把焦点放在当前栏目；按向下进入内容，按返回退出详情或播放页。
- 继续观看卡片右上角新增「更多」按钮，按菜单键（Menu）也可打开同一菜单；焦点菜单默认落在「继续播放」。
- 播放页在电视模式下隐藏触摸控件，改用遥控器：
  - OK / 播放暂停键：播放或暂停。
  - 左 / 右：快退或快进 10 秒，并显示提示。
  - 上 / 下：显示顶部信息与快捷键提示。
  - 菜单键：打开选集面板。
  - 媒体上一曲 / 下一曲：切换上一集 / 下一集。
- 搜索页在电视模式下不会自动弹出软键盘；按向下进入输入框，需要输入时再调起键盘。
- 平板模式仍保留原有触控交互，电视模式只改变焦点、间距与遥控器快捷键。

## 明确不支持

- TVBox 中 `type: 3/4` 的 JAR / JS 爬虫源会被跳过，并在站源页给出提示；MoonTV 只接入标准 Apple CMS JSON/XML 接口。
- 直播源（`lives`）暂未接入。
- 下载、投屏、弹幕等不在当前版本范围。
- Jellyfin/Emby/Plex 服务端转码、字幕/音轨切换面板暂未提供；当前使用直接播放（Direct Play），由服务端原始文件与播放器能力决定兼容性。
- Plex 目前以 Token 方式连接，不包含 plex.tv 账号 OAuth 流程。

## 配置格式

### MoonTV / LunaTV

```json
{
  "cache_time": 7200,
  "api_site": {
    "example": {
      "name": "示例源",
      "api": "https://example.com/api.php/provide/vod",
      "detail": "https://example.com"
    }
  }
}
```

订阅地址可以直接粘贴 `...?format=0&source=...`；MoonTV 会按响应内容自动识别 JSON 或 Base58。

### TVBox

```json
{
  "sites": [
    {
      "key": "example",
      "name": "示例源",
      "type": 1,
      "api": "https://example.com/api.php/provide/vod"
    }
  ]
}
```

TVBox 的 `urls` 子配置也会递归加载（最多 12 个）。相对路径会按配置来源补全。

## 连接媒体服务器

在「媒体库」页选择 Jellyfin / Emby / Plex，填写：

- 服务器地址：例如 `http://192.168.1.20:8096`（Jellyfin/Emby）或 `http://192.168.1.20:32400`（Plex）。
- Jellyfin/Emby：用户名与密码。
- Plex：账号名（仅显示用）与 `X-Plex-Token`。

如果服务器使用自签名 HTTPS 证书，Android 系统可能拒绝连接；建议先在局域网使用 HTTP，或为服务器配置受信任证书。

## 构建

环境：Flutter 3.50.1 / Dart 3.14、Android SDK 36、JDK 17、NDK 28.2。

```powershell
$env:JAVA_HOME='D:\MiniBoxBuild\jdk17\jdk-17.0.21+9'
$env:ANDROID_HOME='D:\MiniBoxBuild\android-sdk'
$env:PATH='D:\Moonfin\sdk\flutter\bin;' + $env:PATH
flutter pub get
flutter build apk --release --target-platform android-arm64
```

应用 ID 为 `com.moonbox.app`。发布签名读取 `android/key.properties`；仓库附有 `android/key.properties.example`。如果没有这个文件，`flutter build apk --release` 会回退到 debug 签名，方便先跑通源码，但正式分发请自行生成并配置 release keystore。

## 目录

```
lib/
  main.dart                 启动、根路由与媒体库初始化
  models.dart               配置/影片/线路模型、Base58、配置解析
  media/
    media_models.dart       媒体服务器、媒体库、条目、详情模型
    media_api.dart          Jellyfin/Emby/Plex REST 客户端与进度上报
    media_store.dart        媒体账号、媒体库、继续观看状态
  services/config_service.dart
  services/vod_api.dart     Apple CMS JSON/XML 请求与解析
  store/app_store.dart      配置、站源、搜索状态
  ui/
    library_page.dart       媒体库登录与浏览
    favorites_page.dart     服务端/本机收藏列表
    library_detail_page.dart 电影/剧集详情、季与集
    app_shell.dart          双模式导航
    discover_page.dart      站源库浏览
    player_page.dart        共用播放器
    ...
android/                    Android 工程、TV banner、启动图、图标
tool/parser_check.dart      配置解析离线自检
```

## 许可

MoonTV 以 GPL-3.0 发布。Moonfin-Core 的原始许可文本见 [`assets/MOONFIN_LICENSE.txt`](assets/MOONFIN_LICENSE.txt)。MoonTV 不提供、不托管任何影片或直播内容；所有内容来自用户自行配置的第三方接口或用户自己的媒体服务器，请遵守当地法律法规并支持正版。
