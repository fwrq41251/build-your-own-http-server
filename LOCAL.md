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

## 写代码

入口是 `src/main.zig`，改完后直接：

```bash
./your_program.sh       # 本地编译并运行，监听 4221
```

`your_program.sh` 每次会先执行 `zig build`，然后运行 `zig-out/bin/main`。Zig 版本是 **0.17.0**，与 `codecrafters.yml` 里的 `buildpack: zig-0.17` 一致。

第一关的代码已经在 `src/main.zig` 里注释好了，取消注释即可。

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

课程仓库缓存在：

```bash
~/.cache/codecrafters/courses/build-your-own-http-server/
```

里面有：

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
