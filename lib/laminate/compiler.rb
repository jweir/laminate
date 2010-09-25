module Laminate
  class Compiler

    # Compiles an HTML-Lua template in a Lua script.
    def compile(name, source)
      # lua is an array of source lines. Each element is one line of generated Lua code.
      # These will be concatenated at the end to return the full lua script.
      lua = []

      lua << "function #{lua_template_function(name)}()"
      # LUA: The _out var is an array (table). Each text fragment is appended
      # to the array. Thus the array serves like the _erbout string buffer in ERB.
      # At the end, all the fragments are joined together to return the result.
      lua << 'local _out = {}; function out(s) table.insert(_out, tostring(s)); end; '

      source.each do |element|
        case element.first
        when :text then add_text(element.last, lua)
        when :code then add_code(element.last, lua)
        when :print then add_print(element.last, lua)
        else raise "Unknown template kind #{element.inspect}"
        end
      end

      lua.pop if lua.last == "\n" || lua.last == ''
      lua << "return table.concat(_out)"
      lua << "end"
      lua.join("\n")
    end

    def lua_template_function(name)
      "_template_#{name}".gsub(/[ \.]/,'_')
    end

    protected

    def add_text(str, lua)
      str.each_line do |line|
        lua << "table.insert(_out, [===[#{line}]===]);"
      end
    end

    def add_code(code, lua)
      code.each_line do |line|
        lua.last << "#{line}"
      end
    end

    def add_print(code, lua)
      code.each_line do |line|
        lua.last << "table.insert(_out, #{line});"
      end
    end

    def blank?(str)
      str.nil? || str.strip == ''
    end
  end
end
