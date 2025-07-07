-- Load explcheck.
local new_issues = require("explcheck-issues")
local parsers = require("explcheck-parsers")
local semantic_analysis = require("explcheck-semantic-analysis")
local utils = require("explcheck-utils")

local csname_types = semantic_analysis.csname_types
local statement_confidences = semantic_analysis.statement_confidences
local statement_types = semantic_analysis.statement_types

local DEFINITELY = statement_confidences.DEFINITELY
local FUNCTION_DEFINITION = statement_types.FUNCTION_DEFINITION
local TEXT = csname_types.TEXT

-- Process all expl3 files.
local files = assert(io.open("files.txt", "r"))
local function_seen_names, function_seen_pathnames = {}, {}
local function_names, function_pathnames = {}, {}
for pathname in files:lines() do
  local issues = new_issues()
  local file = assert(io.open(pathname, "r"))
  local content = assert(file:read("*a"))
  assert(file:close())
  local results = {}
  local options = {fail_fast = false}
  utils.process_with_all_steps(pathname, content, issues, results, options)

  -- Extract the function definitions from the analysis results.
  local statement_segments = {}
  for part_number, part_statements in ipairs(results.statements) do
    table.insert(statement_segments, part_statements)
    local part_replacement_texts = results.replacement_texts[part_number]
    for _, nested_statements in ipairs(part_replacement_texts.statements) do
      table.insert(statement_segments, nested_statements)
    end
  end
  for _, statements in ipairs(statement_segments) do
    for _, statement in ipairs(statements) do
      if statement.type == FUNCTION_DEFINITION and statement.confidence == DEFINITELY then
        local function_name
        if type(statement.defined_csname) == "string" then
          function_name = statement.defined_csname
        elseif statement.defined_csname.type == TEXT then
          function_name = statement.defined_csname.payload
        end
        if function_name and lpeg.match(parsers.expl3like_function_csname, function_name) then
          if function_seen_names[function_name] == nil then
            table.insert(function_names, function_name)
            function_seen_names[function_name] = true
            function_pathnames[function_name] = {}
            function_seen_pathnames[function_name] = {}
          end
          if function_seen_pathnames[function_name][pathname] == nil then
            table.insert(function_pathnames[function_name], pathname)
            function_seen_pathnames[function_name][pathname] = true
          end
        end
      end
    end
  end
end
assert(files:close())

-- Create a LaTeX source file listing all functions and where they are defined.
local function function_name_sort_key(name)
  return name:gsub("^[^%a]+", ""):lower()
end
table.sort(function_names, function(first_name, second_name)
  return function_name_sort_key(first_name) < function_name_sort_key(second_name)
end)
local file = assert(io.open("functions.generated.tex", "w"))
for _, function_name in ipairs(function_names) do
  assert(file:write([[\subsection*{Function \protect\cs{]] .. function_name .. "}}\n"))
  assert(file:write([[\UseName{index}[functions]{]] .. function_name_sort_key(function_name) .. [[@\cs{]] .. function_name .. "}}\n"))
  assert(file:write([[Function \cs{]] .. function_name .. "} is defined in these files:\n"))
  assert(file:write([[\begin{enumerate}]] .. "\n"))
  assert(file:write([[\footnotesize]] .. "\n"))
  table.sort(function_pathnames[function_name])
  for _, pathname in ipairs(function_pathnames[function_name]) do
    local basename = utils.get_basename(pathname)
    assert(file:write([[\item\filename{]] .. pathname .. "}\n"))
    assert(file:write([[\UseName{index}[files]{\filename{]] .. basename .. "}}\n"))
  end
  assert(file:write([[\end{enumerate}]] .. "\n"))
end
assert(file:close())
