require_relative 'command'

class GoToDir < Command
  attr_reader :dir
  def initialize(env_config,dir='.')
    super(env_config,"Go to directory: #{dir}")
    @dir = dir
    @env_config=env_config
  end
  def action
    "cd \\\"#{dir}\\\"\n"
  end
end
