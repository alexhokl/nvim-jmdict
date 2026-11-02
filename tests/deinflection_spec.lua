-- Tests for verb deinflection support.
-- Covers:
--   * deinflect() unit tests (pure function, no index needed)
--   * find_entries() integration: conjugated form → dictionary entry

local h = require("tests.helpers")
local plugin = require("nvim-jmdict")
local internal = plugin._internal

local function reset_options()
  plugin.options = plugin._defaults_for_test()
  plugin._index = nil
end

local function silence_notify()
  internal.set_notify(function() end)
end

-- Helper: check that `word` is contained in the deinflect candidates.
local function has_candidate(word, candidates)
  for _, c in ipairs(candidates) do
    if c == word then return true end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- deinflect() unit tests
-- ---------------------------------------------------------------------------

describe("deinflect", function()
  before_each(function()
    reset_options()
    silence_notify()
  end)

  -- Ichidan (る-verb) forms
  describe("Ichidan (る-verb) forms", function()
    it("食べた → 食べる (past)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べた")))
    end)

    it("食べて → 食べる (te-form)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べて")))
    end)

    it("食べない → 食べる (negative)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べない")))
    end)

    it("食べます → 食べる (polite)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べます")))
    end)

    it("食べました → 食べる (polite past)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べました")))
    end)

    it("食べません → 食べる (polite negative)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べません")))
    end)

    it("食べなかった → 食べる (negative past)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べなかった")))
    end)

    it("食べられる → 食べる (passive/potential)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べられる")))
    end)

    it("食べさせる → 食べる (causative)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べさせる")))
    end)

    it("食べさせられる → 食べる (causative-passive)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べさせられる")))
    end)

    it("食べれば → 食べる (conditional)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べれば")))
    end)

    it("食べよう → 食べる (volitional)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べよう")))
    end)

    it("食べている → 食べる (te-iru progressive)", function()
      assert.is_true(has_candidate("食べる", internal.deinflect("食べている")))
    end)
  end)

  -- Godan (う-verb) forms
  describe("Godan (う-verb) forms", function()
    -- く column
    it("書いた → 書く (く past)", function()
      assert.is_true(has_candidate("書く", internal.deinflect("書いた")))
    end)

    it("書いて → 書く (く te-form)", function()
      assert.is_true(has_candidate("書く", internal.deinflect("書いて")))
    end)

    it("書かない → 書く (く negative)", function()
      assert.is_true(has_candidate("書く", internal.deinflect("書かない")))
    end)

    it("書きます → 書く (く polite)", function()
      assert.is_true(has_candidate("書く", internal.deinflect("書きます")))
    end)

    it("書ける → 書く (く potential)", function()
      assert.is_true(has_candidate("書く", internal.deinflect("書ける")))
    end)

    it("書こう → 書く (く volitional)", function()
      assert.is_true(has_candidate("書く", internal.deinflect("書こう")))
    end)

    -- む column
    it("飲んだ → 飲む (む past)", function()
      assert.is_true(has_candidate("飲む", internal.deinflect("飲んだ")))
    end)

    it("飲んで → 飲む (む te-form)", function()
      assert.is_true(has_candidate("飲む", internal.deinflect("飲んで")))
    end)

    it("飲まない → 飲む (む negative)", function()
      assert.is_true(has_candidate("飲む", internal.deinflect("飲まない")))
    end)

    it("飲みます → 飲む (む polite)", function()
      assert.is_true(has_candidate("飲む", internal.deinflect("飲みます")))
    end)

    -- す column
    it("話した → 話す (す past)", function()
      assert.is_true(has_candidate("話す", internal.deinflect("話した")))
    end)

    it("話して → 話す (す te-form)", function()
      assert.is_true(has_candidate("話す", internal.deinflect("話して")))
    end)

    it("話します → 話す (す polite)", function()
      assert.is_true(has_candidate("話す", internal.deinflect("話します")))
    end)

    it("話せる → 話す (す potential)", function()
      assert.is_true(has_candidate("話す", internal.deinflect("話せる")))
    end)

    -- る column (Godan る)
    it("走った → 走る (る Godan past)", function()
      assert.is_true(has_candidate("走る", internal.deinflect("走った")))
    end)

    it("走って → 走る (る Godan te-form)", function()
      assert.is_true(has_candidate("走る", internal.deinflect("走って")))
    end)

    it("走ります → 走る (る Godan polite)", function()
      assert.is_true(has_candidate("走る", internal.deinflect("走ります")))
    end)

    -- う column
    it("言った → 言う (う past)", function()
      assert.is_true(has_candidate("言う", internal.deinflect("言った")))
    end)

    it("言わない → 言う (う negative)", function()
      assert.is_true(has_candidate("言う", internal.deinflect("言わない")))
    end)

    it("言います → 言う (う polite)", function()
      assert.is_true(has_candidate("言う", internal.deinflect("言います")))
    end)

    -- Regression: the す progressive rule used to be "していている"
    it("話している → 話す (す progressive)", function()
      assert.is_true(has_candidate("話す", internal.deinflect("話している")))
    end)

    it("話していた → 話す (す progressive past)", function()
      assert.is_true(has_candidate("話す", internal.deinflect("話していた")))
    end)
  end)

  -- Chained forms: derived stems conjugated further
  describe("chained forms", function()
    local cases = {
      -- potential
      { "書けました", "書く" },
      { "書けます", "書く" },
      { "書けた", "書く" },
      { "書けない", "書く" },
      -- passive
      { "書かれました", "書く" },
      { "書かれた", "書く" },
      -- causative
      { "書かせました", "書く" },
      { "書かせた", "書く" },
      -- causative-passive
      { "書かせられる", "書く" },
      { "書かされる", "書く" },
      { "書かせれる", "書く" },
      { "書かせられました", "書く" },
      { "飲まされた", "飲む" },
      { "食べさせられました", "食べる" },
      { "食べさせれる", "食べる" },
    }
    for _, case in ipairs(cases) do
      local word, dict = case[1], case[2]
      it(word .. " → " .. dict, function()
        assert.is_true(has_candidate(dict, internal.deinflect(word)))
      end)
    end
  end)

  -- Irregular verb forms
  describe("Irregular verb forms (する / くる)", function()
    it("した → する", function()
      assert.is_true(has_candidate("する", internal.deinflect("した")))
    end)

    it("して → する", function()
      assert.is_true(has_candidate("する", internal.deinflect("して")))
    end)

    it("しない → する", function()
      assert.is_true(has_candidate("する", internal.deinflect("しない")))
    end)

    it("します → する", function()
      assert.is_true(has_candidate("する", internal.deinflect("します")))
    end)

    it("しました → する", function()
      assert.is_true(has_candidate("する", internal.deinflect("しました")))
    end)

    it("きた → くる", function()
      assert.is_true(has_candidate("くる", internal.deinflect("きた")))
    end)

    it("きて → くる", function()
      assert.is_true(has_candidate("くる", internal.deinflect("きて")))
    end)

    it("こない → くる", function()
      assert.is_true(has_candidate("くる", internal.deinflect("こない")))
    end)

    it("きます → くる", function()
      assert.is_true(has_candidate("くる", internal.deinflect("きます")))
    end)
  end)

  -- Compound する verbs
  describe("Compound する verbs", function()
    it("勉強した → 勉強する", function()
      assert.is_true(has_candidate("勉強する", internal.deinflect("勉強した")))
    end)

    it("勉強して → 勉強する", function()
      assert.is_true(has_candidate("勉強する", internal.deinflect("勉強して")))
    end)

    it("勉強しない → 勉強する", function()
      assert.is_true(has_candidate("勉強する", internal.deinflect("勉強しない")))
    end)

    it("勉強します → 勉強する", function()
      assert.is_true(has_candidate("勉強する", internal.deinflect("勉強します")))
    end)
  end)

  -- Edge cases
  describe("edge cases", function()
    it("returns empty list for empty string", function()
      local c = internal.deinflect("")
      assert.are.equal(0, #c)
    end)

    it("does not return the original word as a candidate", function()
      -- 食べる is already a dictionary form; deinflect should not echo it.
      local c = internal.deinflect("食べる")
      for _, v in ipairs(c) do
        assert.are_not.equal("食べる", v)
      end
    end)

    it("returns no duplicates", function()
      local c = internal.deinflect("食べた")
      local seen = {}
      for _, v in ipairs(c) do
        assert.is_nil(seen[v], "duplicate candidate: " .. v)
        seen[v] = true
      end
    end)
  end)
end)

-- ---------------------------------------------------------------------------
-- find_entries integration: conjugated form → dictionary entry
-- ---------------------------------------------------------------------------

describe("find_entries with deinflection", function()
  local idx = {
    entries = {
      { h = "食べる（たべる）", pos = "v1", g = { "to eat" } },
      { h = "書く（かく）", pos = "v5k", g = { "to write" } },
      { h = "勉強（べんきょう）", pos = "n, vs", g = { "study" } },
      { h = "する", pos = "vs-i", g = { "to do" } },
      { h = "話す（はなす）", pos = "v5s", g = { "to talk" } },
      { h = "飲む（のむ）", pos = "v5m", g = { "to drink" } },
      { h = "飲める（のめる）", pos = "v1", g = { "to be able to drink" } },
    },
    keys = {
      ["食べる"] = { 1 }, ["書く"] = { 2 }, ["勉強する"] = { 3 }, ["する"] = { 4 },
      ["話す"] = { 5 }, ["飲む"] = { 6 }, ["飲める"] = { 7 },
    },
  }

  local function heads(entries)
    local out = {}
    for _, e in ipairs(entries or {}) do out[#out + 1] = e.h end
    return out
  end

  it("resolves Ichidan past 食べた", function()
    assert.are.same({ "食べる（たべる）" }, heads(internal.find_entries(idx, "食べた")))
  end)

  it("resolves Godan polite 書きます", function()
    assert.are.same({ "書く（かく）" }, heads(internal.find_entries(idx, "書きます")))
  end)

  it("resolves compound する verb 勉強した", function()
    assert.are.same({ "勉強（べんきょう）" }, heads(internal.find_entries(idx, "勉強した")))
  end)

  it("resolves bare した to する", function()
    assert.are.same({ "する" }, heads(internal.find_entries(idx, "した")))
  end)

  it("resolves Godan す progressive 話している", function()
    assert.are.same({ "話す（はなす）" }, heads(internal.find_entries(idx, "話している")))
  end)

  it("resolves chained potential polite past 書けました", function()
    assert.are.same({ "書く（かく）" }, heads(internal.find_entries(idx, "書けました")))
  end)

  it("resolves colloquial causative-passive 書かせれる", function()
    assert.are.same({ "書く（かく）" }, heads(internal.find_entries(idx, "書かせれる")))
  end)

  it("uses only the shallowest deinflection depth that matches", function()
    -- 飲めました → 飲める (depth 1) → 飲む (depth 2); 飲む must not be added.
    assert.are.same({ "飲める（のめる）" }, heads(internal.find_entries(idx, "飲めました")))
  end)

  it("returns nil when nothing deinflects to a known word", function()
    assert.is_nil(internal.find_entries(idx, "zzz全然不明zzz"))
  end)
end)
