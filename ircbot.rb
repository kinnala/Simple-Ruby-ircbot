require "socket"
require "net/http"

class IRC_Module

    def initialize(server, nick, admin)
        @my_server = server
        @my_nick = nick
        @my_admin = admin
    end

    def hooks
        ["cmd1", "cmd2", "cmd3"]
    end

    def send(target, msg)
        @msgs.push("PRIVMSG #{target} :#{msg}")
    end

    def notify_admin(msg)
        self.send(@my_admin,msg)
    end

    def answer(msg)
        send(@target, msg)
    end

    def run(hook, data)
        @msgs = []

        @nick = data[0]
        @user = data[1]
        @host = data[2]
        if data[3] == @my_nick
            @target = @nick
        else
            @target = data[3]
        end

        @params = data[4].split

        if self.respond_to?(hook) then
            eval(hook)
        else
            notify_admin "Faulty plugin: \"#{self.class.name}\". Not responding to hook \"#{hook}\"."
        end
        @msgs
    end

end

class IRC

    def initialize(server, port, nick, admin)
        @server = server
        @port = port
        @nick = nick
        @admin = admin
        @modules = Array.new
    end

    def send(msg)
        puts "--> #{msg}"
        @irc.send "#{msg}\n", 0
    end

    def notify(msg)
        puts "!! #{msg}"
    end

    def connect()
        notify "Connecting to #{@server}:#{@port} ..."
        @irc = TCPSocket.open(@server, @port)
        send "USER rbmodu rbmodu rbmodu :rbmodu rbmodu"
        send "NICK #{@nick}"
    end

    def loaded?(name)
        @modules.each { |mod|
            if mod.class.name == name then
                return true
            end
        }
        return false
    end

    def find_module(hook)
        @modules.each { |mod|
            if mod.hooks.include? hook then
                return mod
            end
        }
        return nil
    end

    def unload_module(name)
        if loaded? name then
            @modules.delete_if { |mod| mod.class.name == name }
            notify "Unloaded module \"#{name}\"."
        else
            notify "Error when unloading \"#{name}\": Module was not loaded."
        end
    end

    def load_module(name, code)
        if loaded? name then
            unload_module(name)
        end
        begin
            Object.class_eval code
            @modules << eval(name).new(@server, @nick, @admin)
            notify "Loaded module \"#{name}\"."
        rescue Exception => detail
            notify "Error while loading module: #{detail.message()}"
        end
    end

    def load_module_url(name, url)
        notify "Loading module \"#{name}\" from #{url} ..."
        part = url.partition("/")
        Net::HTTP.start(part[0]) { |http|
            code = http.get("/#{part[2]}").body
            load_module(name, code)
        }
    end

    def load_module_file(name, filename)
        notify "Loading module \"#{name}\" from file #{filename} ..."
        file = File.open(filename, "rb")
        code = file.read
        load_module(name, code)
    end

    def handle_server_input(s)
        case s.strip
            when /^PING :(.+)$/i
                notify "Server pinged"
                send "PONG :#{$1}"
            when /^:#{@admin}!(.+?)@(.+?)\sPRIVMSG\s(.+)\s:%%(.+)$/i
                str = "#{$4}"
                begin
                    str.untaint
                    eval(str)
                rescue Exception => detail
                    notify detail.message()
                end
            when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+)\s:!(\S+)(\s.+)?$/i
                data = ["#{$1}","#{$2}","#{$3}","#{$4}","#{$6}"]
                hook = "#{$5}"
                mod = find_module(hook)
                if mod != nil then
                    begin
                        msgs = mod.run(hook, data)
                        msgs.each { |msg| send msg }
                    rescue Exception => detail
                        notify "Error when running module \"#{mod.class.name}\": #{detail.message}"
                    end
                end
            else
                puts "<-- #{s}"
        end
    end

    def run()
        until @irc.eof? do
            s = @irc.gets
            handle_server_input(s)
        end
    end

end

irc = IRC.new("irc.cs.hut.fi", 6667, "spudrespadre", "knl")
irc.connect()
irc.run()
