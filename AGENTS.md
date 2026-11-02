# AGENTS.md

Compact context for agents working in this repo. Read before editing.

## Layout

Single-file Neovim plugin. All runtime code lives in `lua/nvim-jmdict.lua`.
There is no `plugin/` autoload directory; the plugin only activates when the
user calls `require("nvim-jmdict").setup{}`.

The Lua module name contains a hyphen: `require("nvim-jmdict")`. Do not rename
without updating the loader.

## Dictionary format

The plugin reads a JMdict **JSON** file: a top-level array of entries
`{ id, kanji?: [{ text }], kana: [{ text, noKanji? }], sense: [{ partOfSpeech,
gloss: [{ lang, text, type? }], info?, xref? }] }`. The full file is about
56 MB / 219k entries; `vim.json.decode` handles it in about 350 ms.

Default dictionary path: `stdpath('data') .. "/jmdict.json"`.
Default cache path: `stdpath('cache') .. "/nvim-jmdict-index.json"`.

The cache is the compact index serialized as JSON:
`{ entries = { { h, pos, g = { gloss... } } }, keys = { [text] = { entry_idx... } } }`.
`h` is the headword (`研究（けんきゅう）`, or kana alone), `pos` the first sense's
part-of-speech tags, `g` every English gloss of every sense. `keys` covers all
kanji forms and kana readings. Entries without English glosses are dropped.
JSON was chosen over a `loadfile`-able Lua table to avoid Lua constant limits
on a table this size. The cache is mtime-invalidated against the source.

## Testing

Tests use `plenary.busted` orchestrated via `Taskfile.yml`.

```sh
task test                                       # full suite
task test:file -- tests/<spec>_spec.lua         # single file
task clean                                      # drop vendored plenary
```

`task deps` clones plenary into `.deps/plenary.nvim` (gitignored). The headless
runner is invoked with `tests/minimal_init.lua`; do not load tests through your
personal Neovim config.

Use `plugin._internal` (test-only surface) and `plugin._defaults_for_test()`.
The fixture `tests/fixtures/jmdict_sample.json` is a small hand-written JMdict
subset. Stub `vim.ui.select` to drive the picker and `vim.api.nvim_echo` in
any test that exercises `report_error`.

## Behaviour (agreed design)

- **Picker**: `vim.ui.select` always opens, even for a single entry; one row
  per entry formatted `headword [pos] gloss; gloss`. No row limit; id order.
- **Insertion**: chosen entry's glosses joined by `gloss_separator`, wrapped
  by `insert_format` (default `" (%s)"`), inserted after the word.
- **Normal mode**: longest-prefix match from the cursor character
  (`find_longest_prefix`), up to `max_prefix_length` characters. At each
  length, exact match first, then deinflection; longest length wins. Insert
  after the matched text as written in the buffer.
- **Visual mode**: exact selection (newlines stripped, trimmed), then
  deinflection (`find_entries`).
- **Deinflection**: `deinflect()` is ported from `../nvim-kanji-to-hiragana`;
  candidates are over-generated. Rules are chained breadth-first up to
  `MAX_DEINFLECT_DEPTH` (書けました → 書ける → 書く), because derived stems
  conjugate like Ichidan verbs. `deinflect_levels()` groups candidates by
  depth; `find_entries` unions the entries of every candidate at the
  shallowest depth that has any hit, so chained candidates never add picker
  rows to a word that resolves in fewer steps.

## Architecture quirks

- **Async picker**: handlers capture the insertion position *before* calling
  `vim.ui.select` and insert via `nvim_buf_set_text` in the callback. Do not
  assume the cursor is still where it started.
- **Multibyte insertion math**: the `'>` mark gives the byte offset of the
  *first byte* of the last character; `insert_after_mark` skips the full UTF-8
  codepoint width. Retest with 1/2/3/4-byte characters if you touch it.
- **Error visibility**: errors go through `report_error()` →
  `nvim_echo(chunks, true, {})`, not `vim.notify` at ERROR level.

## Conventions

- 2-space indent, no trailing whitespace, double-quoted strings.
- `luac -p lua/nvim-jmdict.lua` for a quick syntax check before running the
  test suite.
