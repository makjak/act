-- command line interfact to act api
-- you will need the act script

local historyFile = "history"
local macroFile = "macro"

local function serialize(o, indent)
  local s = ""
  indent = indent or ""
  if type(o) == "number" then
    s = s .. indent .. tostring(o)
  elseif type(o) == "string" then
    if o:find("\n") then
      s = s .. indent .. "[[\n" .. o:gsub("\"", "\\\"") .. "]]"
    else
      s = s .. indent .. string.format("%q", o)
    end
  elseif type(o) == "table" then
    s = s .. "{\n"
    for k,v in pairs(o) do
      if type(v) == "table" then
        s = s .. indent .. "  [" .. serialize(k) .. "] = " .. serialize(v, indent .. "  ") .. ",\n"
      else
        s = s .. indent .. "  [" .. serialize(k) .. "] = " .. serialize(v) .. ",\n"
      end
    end
    s = s .. indent .. "}"
  else
    error("cannot serialize a " .. type(o))
  end
  return s
end

function flatten(list)
  if type(list) ~= "table" then return {list} end
  local flat_list = {}
  for _, elem in ipairs(list) do
    for _, val in ipairs(flatten(elem)) do
      flat_list[#flat_list + 1] = val
    end
  end
  return flat_list
end

local function saveFile(fileName, table)
  local f = io.open(".act." .. fileName, "w")
  f:write(fileName .. " =\n")
  f:write(serialize(table))
  f:close()
end

local function loadFile(fileName)
  local f = loadfile(".act." .. fileName)
  if f then f() end
end

loadFile("history")
history = history or {}
loadFile("macro")
macro = macro or {}

local tArgs = { ... }
if #tArgs == 0 then
  print( "Usage: do <list of commands>" )
  print( "       do history" )
  print( "       do save <name>" )
  print( "       do <name>" )
  print( "" )
  print( "Saved Commands:" )
  for key, value in pairs(macro) do
    print("       "..key.." : "..serialize(value))
  end
  return
end

os.loadAPI("apis/act")
local cmd = tArgs[1]
if cmd == "history" then
  if #history > 0 then
    for i, v in ipairs(history) do
      if v:find("\n") then
        print("[[\n"..v.."]]")
      else
        print(v)
      end
    end
  else
    print("no history")
  end
elseif cmd == "save" then
  local macro_name = tArgs[2]
  if macro_name ~= nil then
    if macro[macro_name] == nil then
      if #history > 0 then
        macro[macro_name] = history[#history]
        saveFile(macroFile, macro)
      else
        print("no history")
      end
    else
      print("macro name is not unique)")
    end
  else
    print("enter macro name (must be unique)")
  end
elseif cmd == "macro" then
  local macro_name = tArgs[2]
  if macro_name ~= nil then
    if macro[macro_name] == nil then
      -- interactive mode
      local more = ""
      local lines = {}
      while more ~= "]]" do
        if more ~= "" then
          -- macro mode commands
          local ast = act.parse(more, "repeater")
          if ast then
            local srcTable = {"("}
            local repeatlines = ast.repeatlines or 1
            for i = 1, repeatlines do
              table.insert(srcTable, 2, table.remove(lines))
            end
            more = more:gsub("^%s*%d*(.*)$", "%1")
            table.insert(srcTable, more)
            table.insert(lines, srcTable)
            local src = table.concat(flatten(lines), "\n")
            ast = act.parse(src)
            if ast then
              ast.count = ast.count - 1
              act.interpret(ast)
            end
          else
            local ast, error = act.parse(more)
            if ast then
              table.insert(lines, more)
              act.interpret(ast)
            else
              print(error)
            end
          end
        end
        more = io.read()
      end
      local plan = table.concat(flatten(lines), "\n").."\n"
      macro[macro_name] = plan
      saveFile(macroFile, macro)
    else
      print("macro name is not unique")
    end
  else
    print("enter macro name (must be unique)")
  end
elseif macro[cmd] then
  local plan = macro[cmd]
  print(plan)
  act.act(plan)
else
  local plan
  if cmd:sub(1,2) == "[[" then
    table.remove(tArgs, 1)
    if #cmd > 2 then
      table.insert(tArgs, cmd:sub(3).."\n")
    end
    local more = ""
    while not more:find("]]$") do
      if more ~= "" then
        table.insert(tArgs, more.."\n")
      end
      more = io.read()
    end
    table.insert(tArgs, more:sub(1, -3))
    plan = table.concat(tArgs, "")
    if plan:sub(#plan) ~= "\n" then
      plan = plan .. "\n"
    end
  else
    plan = table.concat(tArgs, " ")
  end
  local ast, error = act.parse(plan)
  if ast then
    if #history >= 100 then
      table.remove(history, 1)
    end
    table.insert(history, plan)
    saveFile(historyFile, history)
    act.interpret(ast)
  else
    print("Error in act script:\n")
    print(error)
  end
end