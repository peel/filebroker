class Command
  attr_reader :description,:env_config
  def initialize(env_config,description)
    @description = description
    @env_config = env_config
  end
  def smb
    "echo \"#{action}\" | smbclient -E -g -A #{env_config.authfile} -p #{env_config.port} //#{env_config.address}/#{env_config.share} 2>&1"
  end
  def execute
    @sys.exec(smb).split("\n")
  end
end

class CompositeCommand < Command
  def initialize(env_config)
    @env_config=env_config
    @commands = []
  end
  def <<(cmd)
    @commands << cmd
  end
  def add_command(cmd)
    @commands << cmd
  end
  def action
    @commands.map{|cmd| cmd.action}.join
  end
  def description
    @commands.join
  end
end
