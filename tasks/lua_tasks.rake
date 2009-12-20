namespace :lua do

  def lua_path
    @build_path ||= File.expand_path(File.dirname(__FILE__) + '/../lua')
  end

  def lua_src
    @src ||= [lua_path, "lua-5.1.4"].join("/")
  end

  def current_path
    @current_path ||= File.expand_path(File.dirname(__FILE__))
  end

  def command(label, *commands)
    puts label
    commands.each {|c| puts `#{c.lstrip}`}
    puts "\n\n"
  end

  def build
    command "Create lua directory", %{ mkdir -p #{lua_path} }
    command "Get lua", %{ cd #{lua_path}; wget http://www.lua.org/ftp/lua-5.1.4.tar.gz }
    command "Uncompress lua", %{ cd #{lua_path}; tar xzvf lua-5.1.4.tar.gz }
    command "Copy custom alarm lib to src", %{ cp #{current_path}/lalarm.c #{lua_src}/src}
    #command "Add alarm to temporary Makefile", <<-COMMAND
`sed '/LIB_O=.*/ {
  N
  /\\n.*/ {
    s/LIB_O=.*\\n.*/& lalarm.o/
    }
  }' #{lua_src}/src/Makefile > #{lua_src}/src/Makefile.new`
#    COMMAND
    command "Add new build commands to Makefile",
      %{ echo -e "lalarm.o: lalarm.c\n\n" >> #{lua_src}/src/Makefile.new},
      %{ echo -e "liblua.dylib: \\$(CORE_O) \\$(LIB_O)\\n\\t\\$(CC) -dynamiclib -o \\$@ \\$^ \\$(LIBS)\\n" >> #{lua_src}/src/Makefile.new },
      %{ echo -e "\\$(LUA_SO): \\$(CORE_O) \\$(LIB_O)\\n\\t\\$(CC) -o $@ -shared \\$?" >> #{lua_src}/src/Makefile.new }
    command "Move tempoary Makefile", %{cp #{lua_src}/src/Makefile.new #{lua_src}/src/Makefile}
    command "Make lua", %{cd #{lua_src}; make clean; make macosx; make -C src liblua.dylib; sudo cp src/liblua.dylib /usr/local/lib/; sudo make macosx install}
  end


  desc 'Build a custom version of Lua with alarm'
  task :build do |t|
    build
  end
end
