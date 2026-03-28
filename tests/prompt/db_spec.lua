local db = require("prompt.db")

describe("prompt.db", function()
  local test_db = "/tmp/test_prompt_db_" .. os.time() .. ".db"

  before_each(function()
    os.remove(test_db)
    db.setup(test_db)
  end)

  after_each(function()
    os.remove(test_db)
  end)

  it("creates the database and tables on setup", function()
    local f = io.open(test_db, "r")
    assert.is_not_nil(f)
    if f then
      f:close()
    end
  end)

  it("inserts a prompt and retrieves it by id", function()
    local id = db.insert("hello world", "/home/user/project")
    assert.is_not_nil(id)
    assert.is_true(id > 0)

    local prompt = db.get(id)
    assert.is_not_nil(prompt)
    assert.are.equal("hello world", prompt.body)
    assert.are.equal("/home/user/project", prompt.cwd)
    assert.is_not_nil(prompt.created_at)
  end)

  it("searches prompts with full-text search", function()
    db.insert("refactor the authentication module", "/proj/a")
    db.insert("write unit tests for parser", "/proj/b")
    db.insert("fix authentication bug in login", "/proj/c")

    local results = db.search("authentication")
    assert.are.equal(2, #results)
  end)

  it("returns all prompts ordered by most recent first", function()
    db.insert("first prompt", "/proj")
    db.insert("second prompt", "/proj")
    db.insert("third prompt", "/proj")

    local all = db.all()
    assert.are.equal(3, #all)
    assert.are.equal("third prompt", all[1].body)
    assert.are.equal("first prompt", all[3].body)
  end)

  it("checks if a prompt body already exists", function()
    db.insert("unique prompt", "/proj")
    assert.is_true(db.exists("unique prompt"))
    assert.is_false(db.exists("nonexistent prompt"))
  end)

  it("handles single quotes in prompt body", function()
    local id = db.insert("it's a test with 'quotes'", "/proj")
    local prompt = db.get(id)
    assert.are.equal("it's a test with 'quotes'", prompt.body)
  end)
end)
