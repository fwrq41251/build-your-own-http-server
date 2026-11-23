# 本地 CodeCrafters 环境

这个目录是 CodeCrafters **Build your own HTTP server** 的 Zig starter，已经配置好本地测试，不需要登录 codecrafters.io。

## 快速开始

```bash
cd ~/git/build-your-own-http-server

./test.sh list          # 查看所有关卡和进度
./test.sh show at4      # 阅读某一关的说明
./test.sh               # 跑下一关（自动选第一个未通过的）
./test.sh at4           # 只跑指定关卡
./test.sh at4 ia4 ih0   # 按顺序跑多关
```

通过后关卡会记录在 `.cc-passed` 里，`./test.sh list` 会打上 `[x]`。

## 阅读关卡说明

```bash
./test.sh show             # 不给 slug 时显示下一关
./test.sh show at4         # 渲染后显示
./test.sh show at4 --raw   # 原始 Markdown，和课程仓库完全一致
./test.sh show at4 --tests # 额外显示隐藏的测试说明（剧透）
```

渲染前会自动：

- 在顶部加上 `Stage #N: Name` 标题和进度信息；
- 去掉 `{{#reader_is_bot}}` 模板标记，但保留里面的内容；
- 隐藏 HTML 注释里的测试细节（`--tests` 可展开）；
- 把标成 `javascript`、实际装的是 HTTP 报文的代码块改成纯文本。

渲染器按 `glow` → `bat` → `cat` 自动回退，也可以手动指定：

```bash
CC_RENDERER=plain ./test.sh show at4   # 纯文本
CC_RENDERER=bat   ./test.sh show at4
CC_RENDERER=glow  ./test.sh show at4
```

`glow` 和 `bat` 都是可选的：Linux 上 `pacman -S glow bat`，macOS 上 `brew install glow bat`。不装也能正常阅读，只是没有颜色和排版。

## 在 GitHub 网页上看

仓库里的 [`docs/stages/`](docs/stages/README.md) 有全部 14 关的说明，GitHub 会自动渲染 Markdown，手机浏览器也能看：

- `docs/stages/README.md` — 目录，包含 14 关的表格
- `docs/stages/01-at4.md` … `14-kh7.md` — 每关一页，带「上一关 / 目录 / 下一关」导航
- 和终端一样去掉了模板标记、隐藏了 HTML 注释里的测试细节，HTTP 报文代码块用纯文本显示

这些文件由 `./test.sh docs` 从本地课程缓存（没有缓存时从 GitHub）生成，重复执行结果一致。课程更新后重新生成并提交：

```bash
./test.sh docs
git add docs/stages
git commit -m "Update stage docs"
git push
```

生成的页面已经提交进仓库，所以平时在 GitHub 上看不需要跑任何命令。

## 写代码

入口是 `src/main.zig`，改完后直接：

```bash
./your_program.sh       # 本地编译并运行，监听 4221
```

`your_program.sh` 每次会先执行 `zig build`，然后运行 `zig-out/bin/main`。Zig 版本是 **0.17.0**，与 `codecrafters.yml` 里的 `buildpack: zig-0.17` 一致。

第一关的代码已经在 `src/main.zig` 里注释好了，取消注释即可。

## macOS

脚本本身跨平台，Mac 上只需要：

1. 安装 **Zig 0.17**（版本必须匹配）：
   ```bash
   # 推荐用 mise（和 Linux 上一致）
   mise use -g zig@0.17.0

   # 或者用 Homebrew（确认装的是 0.17）
   brew install zig
   zig version
   ```
2. 克隆仓库后直接运行：
   ```bash
   git clone <your-repo-url> ~/git/build-your-own-http-server
   cd ~/git/build-your-own-http-server
   ./test.sh list
   ```

`test.sh` 只依赖 macOS 自带的 `bash`、`curl`、`awk`、`sed`、`tar`，不需要 `jq`、Python、PyYAML。`glow` / `bat` 只是可选的渲染器，不装也能用。它会根据 `uname` 自动下载对应的 tester：

- Apple Silicon → `v59_darwin_arm64.tar.gz`
- Intel Mac → `v59_darwin_amd64.tar.gz`

`./test.sh show <slug>` 在没缓存课程仓库时会直接从 GitHub 读取说明，所以新机器上不用先 clone 课程仓库。`zig build` 和 `your_program.sh` 在 macOS 上同样可用。

## 关卡

| # | Slug | 名称 | 分组 |
|---:|---|---|---|
| 1 | `at4` | Bind to a port | base |
| 2 | `ia4` | Respond with 200 | base |
| 3 | `ih0` | Extract URL path | base |
| 4 | `cn2` | Respond with body | base |
| 5 | `fs3` | Read header | base |
| 6 | `ej5` | Concurrent connections | base |
| 7 | `ap6` | Return a file | base |
| 8 | `qv8` | Read request body | base |
| 9 | `df4` | Compression headers | HTTP Compression |
| 10 | `ij8` | Multiple compression schemes | HTTP Compression |
| 11 | `cr8` | Gzip compression | HTTP Compression |
| 12 | `ag9` | Persistent connections | Persistent Connections |
| 13 | `ul1` | Concurrent persistent connections | Persistent Connections |
| 14 | `kh7` | Connection closure | Persistent Connections |

## 课程资料在哪

课程仓库可选地缓存在：

```bash
~/.cache/codecrafters/courses/build-your-own-http-server/
```

没有这个缓存也能正常跑测试（`stages.tsv` 已经提交在仓库里），只是 `./test.sh show` 会改为从 GitHub 拉取说明。缓存里有：

- `stage_descriptions/*.md` — 每一关的完整说明
- `course-definition.yml` — 关卡顺序和元信息
- `solutions/zig/` — 官方 Zig 参考实现（剧透，建议做完再看）
- `compiled_starters/zig/` — 原始 starter

也可以直接：

```bash
cd ~/.cache/codecrafters/courses/build-your-own-http-server
cat stage_descriptions/*-at4.md
ls solutions/zig
```

tester 缓存在 `~/.cache/codecrafters/testers/http-server/`。

## 更新课程 / tester

```bash
git -C ~/.cache/codecrafters/courses/build-your-own-http-server pull --ff-only
```

`./test.sh` 会自动查询并下载最新的 http-server tester（第一次运行需要联网）。

## 说明

- 默认跳过 anti-cheat 检查；想跑的话用 `CC_RUN_ANTI_CHEAT=1 ./test.sh`。
- 这是纯本地学习环境，不会向 CodeCrafters 提交成绩。
- 如果以后想接回官方 CLI，在 GitHub 上创建一个空仓库，然后 `git remote add origin <url>` 并 push 即可。
