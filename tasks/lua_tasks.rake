# apt-get install libc-dev
namespace :lua do
  require 'net/http'

  class LuaBuild
    VERSION  = "5.1.4"
    TAR_FILE = "lua-#{VERSION}.tar.gz"
    URL      = "http://www.lua.org/ftp/#{TAR_FILE}"
    PLATFORMS = %w{aix ansi bsd freebsd generic linux macosx mingw posix solaris}

    def initialize(platform)
      if LuaBuild::PLATFORMS.include?(ENV["PLATFORM"])
        build ENV["PLATFORM"]
      else
        error
      end
    end

    def error
      puts "\n\n**********************************************"
      puts "Must include a PLATFORM flag"
      puts "Supported platforms are:\n#{LuaBuild::PLATFORMS.join(" ")}\n\n"
      puts "For example: rake lua:build PLATFORM=macosx"
      puts "**********************************************\n\n"
    end

    def download
      url = URI.parse(URL)
      Net::HTTP.start(url.host) { |http|
        resp = http.get(url.path)
        open([tmp_path, TAR_FILE].join("/"),"wb") { |file|
          file.write(resp.body)
         }
      }
    end

    def lua_path
      @build_path ||= File.expand_path(File.dirname(__FILE__) + '/../lua')
    end

    def tmp_path
      @tmp_path ||= [lua_path, "tmp"].join("/")
    end

    def lua_src
      @src ||= [tmp_path, "lua-5.1.4"].join("/")
    end

    def current_path
      @current_path ||= File.expand_path(File.dirname(__FILE__))
    end

    def command(label, *commands)
      puts label
      commands.each {|c| `#{c.lstrip}`}
    end

    def install
      if @platform == "macosx"
        `cd #{lua_src}; make -C src liblua.dylib; cp src/liblua.dylib #{lua_path}`
      else
        `cd #{lua_src}; cp src/liblua.so #{lua_path}`
      end
    end

    def build(platform)
      @platform = platform
      puts ""
      puts "Create build directory"; FileUtils.mkdir_p tmp_path
      puts "Download Lua source"; download
      command "Uncompress Lua", %{ cd #{tmp_path}; tar xzvf lua-5.1.4.tar.gz }
      command "Copy custom alarm lib to src", %{ cp #{current_path}/../vendor/lalarm.c #{lua_src}/src}
      command "Copy custom Makefiles", %{ cp #{current_path}/../vendor/Makefile #{lua_src}; cp #{current_path}/../vendor/Makefile.src #{lua_src}/src}
      command "Make the lua dynamic library (may take a momemnt)", %{cd #{lua_src}; make clean; make #{platform};}
      puts "Copy dylib or shared object"; install
      #puts "Remove build directory"; FileUtils.rm_rf tmp_path
      puts "Lua should now be installed"
      puts ""
    end
  end

  desc 'Build a custom version of Lua with alarm (requires the PLATFORM)'
  task :build do |t|
    LuaBuild.new ENV["PLATFORM"]
  end
end
