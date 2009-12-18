module Laminate
  class Compiler
    SEPARATOR  = /(do|then|else|elseif|repeat)\s*$/
    CONTROL    = /^\s*(if|while|repeat|until|for|else|elseif|break|end|function)\b/
    ASSIGNMENT = /^\s*[\w\s,]+=[^=]/

    def add_text(str, newline)
      nl = newline ? "\\n" : ""
      str = escape_quotes(str)
      "table.insert(_out, \"#{str}#{nl}\"); "
    end

    def add_code(code, lua)
      if code !~ /^#/  # short circuit comments
        separator  = (code =~ SEPARATOR) ? '' : ';'
        is_control = (code =~ CONTROL)
        is_assignment = (!is_control && code =~ ASSIGNMENT)
        if code =~ /^=(.*)/ || (!is_control && !is_assignment)
          code = $1 || code
          lua.last << "table.insert(_out, #{code})#{separator} "
        else
          lua.last << "#{code}#{separator} "
        end
      end
    end

    # Compiles an HTML-Lua template in a Lua script.
    def compile(name, template_source)
      # lua is an array of source lines. Each element is one line of generated Lua code. 
      # These will be concatenated at the end to return the full lua script.
      lua = []

      lua << "function #{lua_template_function(name)}()"
      # LUA: The _out var is an array (table). Each text fragment is appended 
      # to the array. Thus the array serves like the _erbout string buffer in ERB. 
      # At the end, all the fragments are joined together to return the result.
      lua << 'local _out = {}; function out(s) table.insert(_out, tostring(s)); end; '

      # Split the template by lines. 
      template_source.each_line do |line|
        line.chomp! if line =~ /\n$/
        # Match all the Lua scripts in the line
        matches = line.scan(/(.*?)\{\{(.*?)\}\}([^\{]*)/)
        if matches.empty?
          # No code, so just do line
          lua.last << add_text(line, true)
          lua << ''
        else
          found_text = false
          matches.each do |tuple|
            left  = tuple[0]
            code  = tuple[1]
            right = tuple[2]
            #left.strip! if left.strip == '' # greedy strip code indentation
            found_text ||= (!blank?(left) || !blank?(right))
            lua.last << add_text(left, false) #if left != ''  
            add_code(code, lua)
            lua.last << add_text(right, false) if right != ''
          end
          lua.last << add_text('', true) if true #found_text # LUA: newline if any regular text on the line
          lua << ''
        end
      end
      if lua.last == "\n" || lua.last == ''
        lua.pop
      end
      lua << "return table.concat(_out)"
      lua << "end"
      lua.join("\n")
    end

    def blank?(str)
      str.nil? || str.strip == ''
    end

    def lua_template_function(name)
      "_template_#{name}".gsub(/[ \.]/,'_')
    end

    def escape_quotes(str)
      str.gsub('\"', '\\\\\\"').gsub(/"/,'\"')
    end

  end # class Compiler
end