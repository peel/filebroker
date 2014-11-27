require_relative 'command'

class DeleteFile < Command
  attr_reader :filename
  def initialize(env_config,filename)
    super(env_config,"Delete file: #{filename}")
    @filename = filename
    @env_config = env_config
  end
  def action
    "rm \\\"#{filename}\\\"\n"
  end
end
