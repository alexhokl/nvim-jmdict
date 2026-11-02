# nvim-jmdict

A Neovim plugin that translates Japanese to English using a local
[JMdict](https://www.edrdg.org/jmdict/j_jmdict.html) dictionary in JSON form.
Pick a translation from a list, and the plugin inserts it into the buffer right
after the word:

```
研究者が来た  →  研究者 (researcher)が来た
```

## Requirements

- Neovim 0.10+
- A JMdict JSON file: an array of entries shaped like

  ```json
  {"id":1157170,"kanji":[{"text":"研究"}],"kana":[{"text":"けんきゅう"}],
   "sense":[{"partOfSpeech":["n","vs"],"gloss":[{"lang":"eng","text":"study"}]}]}
  ```

The default expected path is `stdpath("data") .. "/jmdict.json"`
(`~/.local/share/nvim/jmdict.json` on Linux / macOS); override it via
`dictionary_path`.

## Installation

Using `lazy.nvim`:

```lua
{
  "alexhokl/nvim-jmdict",
  config = function()
    require("nvim-jmdict").setup({
      dictionary_path = "~/Desktop/japanese/jmdict.json",
    })
  end,
}
```

## Usage (`<leader>je`)

- **Normal mode**: place the cursor on the first character of a Japanese word
  and press `<leader>je`. Since Japanese text has no spaces, the plugin looks
  up the longest run of characters starting at the cursor that matches a
  dictionary entry (e.g. on 研 in `研究者が来た` it finds 研究者).
- **Visual mode**: select the exact text to look up and press `<leader>je`.

Lookups match both kanji forms and kana readings, so `けんきゅう` finds 研究.
Conjugated verbs are deinflected to their dictionary form (食べました → 食べる);
the translation is inserted after the conjugated text as written. Derived
forms that are conjugated again also resolve, e.g. potential 書けました,
passive 書かれた, causative 書かせました and causative-passive 書かせられる /
書かされる / 書かせれる all resolve to 書く.

A `vim.ui.select` picker always opens, with one row per matching dictionary
entry:

```
研究（けんきゅう） [n, vs, vt] research; study; investigation
```

The chosen entry's English glosses (from every sense) are inserted after the
word as ` (research; study; investigation)`. Entries are listed in dictionary
(id) order with no limit; use a filtering picker (telescope, fzf-lua, …) for
readings with many homophones.

## Configuration

```lua
require("nvim-jmdict").setup({
  visual_mode_keymap = "<leader>je",
  normal_mode_keymap = "<leader>je",
  keymap_options = { noremap = true, silent = true },

  -- Path to the JMdict JSON file
  dictionary_path = vim.fn.stdpath("data") .. "/jmdict.json",

  -- Compact lookup index (auto-managed, mtime-invalidated)
  cache_path = vim.fn.stdpath("cache") .. "/nvim-jmdict-index.json",

  -- string.format pattern for the inserted text; %s receives the glosses
  insert_format = " (%s)",
  -- Separator between glosses, in the picker and in the inserted text
  gloss_separator = "; ",
  -- Normal mode: longest substring (in characters) tried from the cursor
  max_prefix_length = 12,
})
```

## How it works

On the first lookup of a session the plugin decodes the dictionary, builds a
compact index (lookup text → entries with headword, part of speech and English
glosses) and writes it to `cache_path`. Later sessions load the cache instead
(about 0.3 s for the full JMdict, versus about 0.75 s to build). The cache is
rebuilt automatically when the dictionary file's mtime is newer.

## Commands

- `:JmdictRebuildIndex` — delete the cache and rebuild the index from
  `dictionary_path`.

## Limitations

- Deinflection covers verbs only (Ichidan, Godan, する/くる and compound する
  verbs); adjective conjugations are not deinflected.
- Normal mode matches from the cursor forwards, so place the cursor on the
  first character of the word.

## Development

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)'s busted
runner and are orchestrated via [Task](https://taskfile.dev):

```sh
task test               # run the full suite
task test:file -- tests/nvim-jmdict_spec.lua
task clean              # remove vendored test deps
```

The first run vendors plenary into `.deps/plenary.nvim` (gitignored).
