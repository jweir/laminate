module Laminate
  class Compiler

    # Compiles an HTML-Lua template in a Lua script.
    def compile(name, source)
      out = []

      out << "function #{out_template_function(name)}() {"
      # LUA: The _out var is an array (table). Each text fragment is appended
      # to the array. Thus the array serves like the _erbout string buffer in ERB.
      # At the end, all the fragments are joined together to return the result.
      out << 'var _out = []; function out(s){ _out.push(s)};'
      out << ''
      compile_source source, out

      out.pop if out.last == "\n" || out.last == ''
      out << "return _out.join('');"
      out << "}"
      out.join("\n")
    end

    def out_template_function(name)
      "_template_#{name}".gsub(/[ \.]/,'_')
    end

    protected


    def compile_source(source, out)
      source.each do |element|
        case element.first
        when :text then add_text(element.last, out)
        when :code then add_code(element.last, out)
        when :print then add_print(element.last, out)
        else raise "Unknown template kind #{element.inspect}"
        end
      end
    end

    def add_text(text, out)
      out << "_out.push('#{text.gsub(/'/im,"\\\\'").gsub(/\n/im,"\\n")}');"
    end

    def add_code(code, out)
      code.each_line do |line|
        out.last << "#{line.rstrip};"
      end
    end

    def add_print(code, out)
      code.each_line do |line|
        out.last << "_out.push(#{line.rstrip});"
      end
    end

    def blank?(str)
      str.nil? || str.strip == ''
    end
  end
end
