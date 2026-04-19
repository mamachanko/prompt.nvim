local M = {}

local db_path = nil

--- Shell-escape a string for SQL single quotes
---@param s string|nil
---@return string
local function escape(s)
  if s == nil then
    return ""
  end
  return s:gsub("'", "''")
end

--- Run a sqlite3 command and return stdout
---@param args string sqlite3 arguments (flags + SQL)
---@return string
local function exec(args)
  local cmd = string.format("sqlite3 %s %s", vim.fn.shellescape(db_path), args)
  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    error("sqlite3 error: " .. (result or "unknown"))
  end
  return result or ""
end

--- Run a SQL statement (no output expected)
---@param sql string
local function run(sql)
  exec(vim.fn.shellescape(sql))
end

--- Run a query and return rows as a list of tables (JSON mode)
---@param sql string
---@return table[]
local function query(sql)
  local raw = exec("-json " .. vim.fn.shellescape(sql))
  if raw == nil or raw == "" or raw:match("^%s*$") then
    return {}
  end
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok then
    return {}
  end
  return decoded
end

--- Initialize the database schema
---@param path string
function M.setup(path)
  db_path = path
  run([[
    CREATE TABLE IF NOT EXISTS prompts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      body TEXT NOT NULL,
      created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', 'localtime')),
      cwd TEXT
    );
    CREATE VIRTUAL TABLE IF NOT EXISTS prompts_fts USING fts5(body, content=prompts, content_rowid=id);
    CREATE TRIGGER IF NOT EXISTS prompts_ai AFTER INSERT ON prompts BEGIN
      INSERT INTO prompts_fts(rowid, body) VALUES (new.id, new.body);
    END;
    CREATE TRIGGER IF NOT EXISTS prompts_ad AFTER DELETE ON prompts BEGIN
      INSERT INTO prompts_fts(prompts_fts, rowid, body) VALUES('delete', old.id, old.body);
    END;
    CREATE TRIGGER IF NOT EXISTS prompts_au AFTER UPDATE ON prompts BEGIN
      INSERT INTO prompts_fts(prompts_fts, rowid, body) VALUES('delete', old.id, old.body);
      INSERT INTO prompts_fts(rowid, body) VALUES (new.id, new.body);
    END;
  ]])
end

--- Insert a new prompt
---@param body string
---@param cwd string|nil
---@return number id
function M.insert(body, cwd)
  local raw = exec(vim.fn.shellescape(string.format(
    "INSERT INTO prompts (body, cwd) VALUES ('%s', '%s'); SELECT last_insert_rowid();",
    escape(body),
    escape(cwd or "")
  )))
  return tonumber((raw or ""):match("%d+")) or 0
end

--- Get a prompt by ID
---@param id number
---@return table|nil
function M.get(id)
  local rows = query(string.format("SELECT id, body, created_at, cwd FROM prompts WHERE id = %d;", id))
  if #rows == 0 then
    return nil
  end
  return rows[1]
end

--- Full-text search for prompts
---@param term string
---@return table[]
function M.search(term)
  return query(string.format(
    "SELECT p.id, p.body, p.created_at, p.cwd FROM prompts p INNER JOIN prompts_fts f ON p.id = f.rowid WHERE prompts_fts MATCH '%s' ORDER BY p.id DESC;",
    escape(term)
  ))
end

--- Return all prompts, most recent first
---@return table[]
function M.all()
  return query("SELECT id, body, created_at, cwd FROM prompts ORDER BY id DESC;")
end

--- Check if a prompt with the exact body already exists
---@param body string
---@return boolean
function M.exists(body)
  local raw = exec(vim.fn.shellescape(string.format(
    "SELECT COUNT(*) FROM prompts WHERE body = '%s';",
    escape(body)
  )))
  return tonumber(raw) ~= nil and tonumber(raw) > 0
end

return M
