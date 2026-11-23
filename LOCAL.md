# Local CodeCrafters Setup

This directory is the Zig starter for CodeCrafters **Build your own HTTP server**, already configured for local testing without logging in to codecrafters.io.

## Quick start

```bash
cd ~/git/build-your-own-http-server

./test.sh list          # list all stages and progress
./test.sh show at4      # read a stage's instructions
./test.sh               # run the next stage (first one not yet passed)
./test.sh at4           # run one specific stage
./test.sh at4 ia4 ih0   # run several stages in order
```

Passed stages are recorded in `.cc-passed`; `./test.sh list` marks them with `[x]`.

## Reading stage descriptions

```bash
./test.sh show             # show the next stage when no slug is given
./test.sh show at4         # render a stage
./test.sh show at4 --raw   # original Markdown, identical to the course repo
./test.sh show at4 --tests # also show the hidden test notes (spoilers)
```

Before rendering, it automatically:

- adds a `Stage #N: Name` heading and progress line at the top;
- strips the `{{#reader_is_bot}}` template markers but keeps their content;
- hides the test details in HTML comments (`--tests` reveals them);
- turns code blocks labelled `javascript` that actually contain HTTP messages into plain text.

Rendering falls back from `glow` to `bat` to `cat`, and you can force one:

```bash
CC_RENDERER=plain ./test.sh show at4   # plain text
CC_RENDERER=bat   ./test.sh show at4
CC_RENDERER=glow  ./test.sh show at4
```

`glow` and `bat` are optional: `pacman -S glow bat` on Linux, `brew install glow bat` on macOS. Everything still works without them, just without colour or formatting.

## Reading on GitHub

[`docs/stages/`](docs/stages/README.md) contains all 14 stage descriptions, and GitHub renders the Markdown automatically, including on a phone:

- `docs/stages/README.md` — index with a table of all 14 stages
- `docs/stages/01-at4.md` … `14-kh7.md` — one page per stage with Index / Previous / Next navigation
- like the terminal output, template markers are removed, hidden HTML comments stay hidden, and HTTP message blocks are shown as plain text

`./test.sh docs` generates these files from the local course cache (or from GitHub when there is no cache), and repeated runs produce identical output. After the course material changes, regenerate and commit:

```bash
./test.sh docs
git add docs/stages
git commit -m "Update stage docs"
git push
```

The generated pages are committed, so browsing them on GitHub requires no commands.

## Writing code

The entry point is `src/main.zig`. After editing, run:

```bash
./your_program.sh       # build and run locally, listening on 4221
```

`your_program.sh` runs `zig build` first and then executes `zig-out/bin/main`. The Zig version is **0.17.0**, matching `buildpack: zig-0.17` in `codecrafters.yml`.

### Editor support

`mise.toml` pins `zls 0.17.0`, the Zig language server used by editors such as Zed. After cloning, install it with:

```bash
mise install
```

Zed's Zig extension looks up `zls` on `PATH`, so the mise shims must be on your `PATH`. If Zed was already open when `zls` was installed, restart the language server from the command palette (`editor: restart language server`) or reopen the project.

The first stage's code is already in `src/main.zig` as comments; just uncomment it.

## macOS

The scripts are cross-platform. On a Mac you only need to:

1. Install **Zig 0.17** (the version must match):
   ```bash
   # Recommended: mise (same as on Linux)
   mise use -g zig@0.17.0

   # Or Homebrew (make sure it installs 0.17)
   brew install zig
   zig version
   ```
2. Clone the repository and run:
   ```bash
   git clone <your-repo-url> ~/git/build-your-own-http-server
   cd ~/git/build-your-own-http-server
   ./test.sh list
   ```

`test.sh` only needs the `bash`, `curl`, `awk`, `sed` and `tar` that ship with macOS; no `jq`, Python or PyYAML. `glow` / `bat` are optional renderers. It picks the tester for your platform based on `uname`:

- Apple Silicon → `v59_darwin_arm64.tar.gz`
- Intel Mac → `v59_darwin_amd64.tar.gz`

When the course repository isn't cached, `./test.sh show <slug>` reads the descriptions straight from GitHub, so a fresh machine doesn't need to clone the course repo first. `zig build` and `your_program.sh` work the same way on macOS.

## Stages

| # | Slug | Name | Group |
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

## Where the course material lives

The course repository is optionally cached at:

```bash
~/.cache/codecrafters/courses/build-your-own-http-server/
```

Tests work without this cache (`stages.tsv` is committed), but `./test.sh show` will fetch descriptions from GitHub instead. The cache contains:

- `stage_descriptions/*.md` — the full description of every stage
- `course-definition.yml` — stage order and metadata
- `solutions/zig/` — official Zig reference implementation (spoilers; save it for after you finish)
- `compiled_starters/zig/` — the original starter

You can also browse it directly:

```bash
cd ~/.cache/codecrafters/courses/build-your-own-http-server
cat stage_descriptions/*-at4.md
ls solutions/zig
```

The tester is cached under `~/.cache/codecrafters/testers/http-server/`.

## Updating the course / tester

```bash
git -C ~/.cache/codecrafters/courses/build-your-own-http-server pull --ff-only
```

`./test.sh` looks up and downloads the latest http-server tester automatically (the first run needs network access).

## Notes

- Anti-cheat checks are skipped by default; run them with `CC_RUN_ANTI_CHEAT=1 ./test.sh`.
- This is a purely local learning setup; results are never submitted to CodeCrafters.
- To hook the official CLI back up later, create an empty repository on GitHub, then `git remote add origin <url>` and push.
