function _rb_assert(result, err_message)
  if result == nil and err_message ~= nil then
    error(err_message, 3)
  end
  return result
end

function _rb_post_process(ruby_result)
  if type(ruby_result) == 'table' then
    local result
    for k,v in pairs(ruby_result) do
      if type(v) == 'table' then
        result = v
      end
    end
    for k,v in pairs(ruby_result) do
      if type(v) ~= 'table' then
        result[k] = v
      end
    end
    return result
  else
    return ruby_result
  end
end

function debug(t, indent, done)
  if t == nil then
    return '<nil>'
  end
  if (type(t) == 'string' or type(t) == nil) then
    return tostring(t)
  end
  done = done or {}
  indent = indent or ''
  result = ''
  indentchars = '                                                                                                        '
  local nextIndent -- Storage for next indentation value
  for key, value in pairs (t) do
    if type (value) == "table" and not done [value] then
      nextIndent = nextIndent or
          (indent .. indentchars:sub(1, string.len(tostring (key))+2))
          -- Shortcut conditional allocation
      done [value] = true
      result = result .. (indent .. "[" .. tostring (key) .. "] => Table {\\n");
      result = result .. (nextIndent .. "{\\n");
      result = result .. debug (value, nextIndent .. indentchars:sub(1, 2), done) .. "\\n"
      result = result .. (nextIndent .. "}\\n");
    else
      result = result .. (indent .. "[" .. tostring (key) .. "] => " .. tostring (value).."\\n")
    end
  end
  return result
end

function string.escape(val)
  if val == nil then
    return ''
  end
  val = tostring(val)
  result = val:gsub('&', '&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"', '&quot;')
  return result
end

function slice(array, start, length)
  return {unpack(array, start, start+length-1)}
end

function string.trim(str)
    return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

function string.split(str, sep)
    local pos, t = 1, {}
    if #sep == 0 or #str == 0 then return end
    for s, e in function() return string.find(str, sep, pos) end do
        table.insert(t, string.trim(string.sub(str, pos, s-1)))
        pos = e+1
    end
    table.insert(t, string.trim(string.sub(str, pos)))
    return t
end

function include(name, ignore_errors)
  local f, err = loadstring(_load_template(name))
  if not f then
    print("********* LUA: " .. err)
    if ignore_errors then
      return "<!-- error from included template '" .. name .. "': " .. err .. " -->"
    end
    error("Error from included template: '" .. name .. "': " .. err, 0)
  else
    status, result = pcall(f)
    if status then
      return result
    else
      if ignore_errors then
        return "<!-- error from included template '" .. name .. "': " .. result .. " -->"
      end
      error("Error from included template: '" .. name .. "': " .. result, 0)
    end
  end
end