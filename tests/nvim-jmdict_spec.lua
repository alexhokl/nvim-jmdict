local h = require("tests.helpers")
local plugin = require("nvim-jmdict")
local internal = plugin._internal

local FIXTURE = vim.fn.getcwd() .. "/tests/fixtures/jmdict_sample.json"

local function reset_options()
  plugin.options = plugin._defaults_for_test()
  plugin._index = nil
end

local function silence_notify()
  internal.set_notify(function() end)
end

local function heads(entries)
  local out = {}
  for _, e in ipairs(entries or {}) do out[#out + 1] = e.h end
  return out
end

-- Replace vim.ui.select with a picker that records its arguments and picks
-- the `n`th item (or cancels when n is nil). Returns a restore function and
-- the record table.
local function stub_select(n)
  local record = {}
  local restore = h.stub(vim.ui, "select", function(items, opts, on_choice)
    record.items = items
    record.opts = opts
    on_choice(n and items[n] or nil, n)
  end)
  return restore, record
end

local function with_buffer(lines, fn)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  local ok, err = pcall(fn, bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
  if not ok then error(err) end
end

describe("build_index_from_json", function()
  before_each(function()
    reset_options()
    silence_notify()
  end)

  it("indexes kanji forms and kana readings", function()
    local idx = internal.build_index_from_json(FIXTURE)
    assert.are.same(idx.keys["研究"], idx.keys["けんきゅう"])
    assert.are.same(idx.keys["食べる"], idx.keys["喰べる"])
    assert.are.same(idx.keys["今日"], idx.keys["こんにち"])
  end)

  it("keeps entries sharing a reading in dictionary order", function()
    local idx = internal.build_index_from_json(FIXTURE)
    local entries = {}
    for _, i in ipairs(idx.keys["かみ"]) do entries[#entries + 1] = idx.entries[i] end
    assert.are.same({ "紙（かみ）", "神（かみ）" }, heads(entries))
  end)

  it("builds headword, first-sense part of speech and English glosses", function()
    local idx = internal.build_index_from_json(FIXTURE)
    local entry = idx.entries[idx.keys["研究"][1]]
    assert.are.same({
      h = "研究（けんきゅう）",
      pos = "n, vs",
      g = { "study", "research", "investigation" },
    }, entry)
  end)

  it("uses the kana alone as headword for kana-only entries", function()
    local idx = internal.build_index_from_json(FIXTURE)
    assert.are.equal("ゝ", idx.entries[idx.keys["ゝ"][1]].h)
  end)

  it("skips entries without English glosses", function()
    local idx = internal.build_index_from_json(FIXTURE)
    assert.is_nil(idx.keys["無英語"])
  end)

  it("returns nil when file is missing", function()
    local restore = h.stub(vim.api, "nvim_echo", function() end)
    local idx = internal.build_index_from_json("/nonexistent/jmdict.json")
    restore()
    assert.is_nil(idx)
  end)

  it("returns nil on malformed JSON", function()
    local restore = h.stub(vim.api, "nvim_echo", function() end)
    h.with_tempfile("[{not json", function(path)
      assert.is_nil(internal.build_index_from_json(path))
    end)
    restore()
  end)
end)

describe("index cache", function()
  local cache_path

  before_each(function()
    reset_options()
    silence_notify()
    cache_path = vim.fn.tempname() .. "/index.json"
    plugin.options.dictionary_path = FIXTURE
    plugin.options.cache_path = cache_path
  end)

  after_each(function()
    os.remove(cache_path)
  end)

  it("writes the cache on first load and reads it back", function()
    local built = internal.load_index()
    assert.is_not_nil(vim.loop.fs_stat(cache_path))
    local cached = internal.load_cached_index(cache_path, FIXTURE)
    assert.are.same(built, cached)
  end)

  it("ignores a cache older than the dictionary", function()
    internal.load_index()
    local now = os.time()
    h.set_mtime(cache_path, now - 100)
    local dict = vim.fn.tempname()
    h.write_file(dict, h.read_file(FIXTURE))
    h.set_mtime(dict, now)
    assert.is_nil(internal.load_cached_index(cache_path, dict))
    os.remove(dict)
  end)

  it("ignores a corrupt cache", function()
    internal.load_index()
    h.write_file(cache_path, "garbage")
    h.set_mtime(cache_path, os.time() + 100)
    assert.is_nil(internal.load_cached_index(cache_path, FIXTURE))
  end)
end)

describe("lookup", function()
  local idx

  before_each(function()
    reset_options()
    silence_notify()
    idx = internal.build_index_from_json(FIXTURE)
  end)

  it("find_entries matches kanji and kana exactly", function()
    assert.are.same({ "研究（けんきゅう）" }, heads(internal.find_entries(idx, "研究")))
    assert.are.same({ "研究（けんきゅう）" }, heads(internal.find_entries(idx, "けんきゅう")))
  end)

  it("find_longest_prefix prefers the longest match", function()
    local entries, len = internal.find_longest_prefix(idx, "研究者が来た", 1, 12)
    assert.are.same({ "研究者（けんきゅうしゃ）" }, heads(entries))
    assert.are.equal(#"研究者", len)
  end)

  it("find_longest_prefix deinflects before falling back to shorter prefixes", function()
    local entries, len = internal.find_longest_prefix(idx, "食べたい", 1, 12)
    assert.are.same({ "食べる（たべる）" }, heads(entries))
    assert.are.equal(#"食べた", len)
  end)

  it("find_longest_prefix starts at the given byte offset", function()
    local text = "研究者が来た"
    local entries, len = internal.find_longest_prefix(idx, text, #"研究者が" + 1, 12)
    assert.are.same({ "来る（くる）" }, heads(entries))
    assert.are.equal(#"来た", len)
  end)

  it("find_longest_prefix respects max_prefix_length", function()
    local entries = internal.find_longest_prefix(idx, "研究者", 1, 2)
    assert.are.same({ "研究（けんきゅう）" }, heads(entries))
  end)

  it("find_longest_prefix returns nil when nothing matches", function()
    local entries, len = internal.find_longest_prefix(idx, "zzz", 1, 12)
    assert.is_nil(entries)
    assert.are.equal(0, len)
  end)
end)

describe("formatting", function()
  local entry = { h = "研究（けんきゅう）", pos = "n, vs", g = { "study", "research" } }

  before_each(reset_options)

  it("formats picker rows", function()
    assert.are.equal("研究（けんきゅう） [n, vs] study; research", internal.format_item(entry))
  end)

  it("omits empty part of speech", function()
    assert.are.equal("ゝ x", internal.format_item({ h = "ゝ", pos = "", g = { "x" } }))
  end)

  it("formats inserted text with configurable format and separator", function()
    assert.are.equal(" (study; research)", internal.format_insertion(entry))
    plugin.options.insert_format = "[%s]"
    plugin.options.gloss_separator = ", "
    assert.are.equal("[study, research]", internal.format_insertion(entry))
  end)
end)

describe("buffer insertion", function()
  before_each(function()
    reset_options()
    silence_notify()
    plugin._index = internal.build_index_from_json(FIXTURE)
  end)

  it("normal mode inserts after the longest match from the cursor", function()
    with_buffer({ "研究者が来た" }, function(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local restore, record = stub_select(1)
      internal.lookup_and_write_after_current_word()
      restore()
      assert.are.equal(1, #record.items)
      assert.are.same({ "研究者 (researcher)が来た" },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)
  end)

  it("normal mode inserts after conjugated text mid-line", function()
    with_buffer({ "研究者が来た。" }, function(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, #"研究者が" })
      local restore = stub_select(1)
      internal.lookup_and_write_after_current_word()
      restore()
      assert.are.same({ "研究者が来た (to come)。" },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)
  end)

  it("always shows the picker and lists every matching entry", function()
    with_buffer({ "かみ" }, function(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local restore, record = stub_select(2)
      internal.lookup_and_write_after_current_word()
      restore()
      assert.are.same({ "紙（かみ）", "神（かみ）" }, heads(record.items))
      assert.are.same({ "かみ (god; deity)" },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)
  end)

  it("leaves the buffer untouched when the picker is cancelled", function()
    with_buffer({ "研究" }, function(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local restore = stub_select(nil)
      internal.lookup_and_write_after_current_word()
      restore()
      assert.are.same({ "研究" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)
  end)

  it("notifies without opening the picker when nothing matches", function()
    with_buffer({ "zzz" }, function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local messages = {}
      internal.set_notify(function(msg) messages[#messages + 1] = msg end)
      local restore, record = stub_select(1)
      internal.lookup_and_write_after_current_word()
      restore()
      assert.is_nil(record.items)
      assert.are.equal(1, #messages)
    end)
  end)

  it("visual mode inserts after the selection", function()
    with_buffer({ "今日食べた物" }, function(bufnr)
      vim.api.nvim_win_set_cursor(0, { 1, #"今日" })
      vim.cmd("normal! v2l")
      local restore = stub_select(1)
      internal.lookup_and_write_after_visual_selection()
      restore()
      assert.are.same({ "今日食べた (to eat)物" },
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)
  end)
end)
