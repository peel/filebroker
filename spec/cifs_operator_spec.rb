require 'rspec'
require_relative '../lib/cifs/operator'
require_relative '../lib/cifs/commands/commands'
require_relative '../lib/cifs/uri_parser'
require_relative '../lib/cifs/config'

AUTHFILE='/tmp/auth'
SHARE='fes-nemis'
ADDRESS = 'cifs-01.nas-01-ext.pld2.root4.net'
PORT = 445
env = CIFSConfig.new(ADDRESS, PORT,SHARE,AUTHFILE)

describe Command, '#smb' do
  class SomeCommand < Command
    def action
      "lorem\n"
    end
  end
  it "should build a smbclient-wrapped command" do
    cmd = SomeCommand.new(env,nil)
    expect(cmd.smb).to eq "echo \"lorem\n\" | smbclient -E -g -A #{AUTHFILE} -p #{PORT} //#{ADDRESS}/#{SHARE} 2>&1"
  end
end
describe GoToDir, '#action' do
  it "should build a cifs-compatible cd command" do
    cd = GoToDir.new(env,'a')
    expect(cd.action).to eq "cd \\\"a\\\"\n"
  end
  it "should build command to move to current directory" do
    cd = GoToDir.new(env)
    expect(cd.action).to eq "cd \\\".\\\"\n"
  end
  it "should build a smbclient-wrapped command" do
    cd = GoToDir.new(env,'a')
    expect(cd.smb).to eq "echo \"cd \\\"a\\\"\n\" | smbclient -E -g -A #{AUTHFILE} -p #{PORT} //#{ADDRESS}/#{SHARE} 2>&1"
  end
end
describe DeleteFile, '#action' do
  it "should build a cifs-compatible cd command" do
    rm = DeleteFile.new(env,'f.txt')
    expect(rm.action).to eq "rm \\\"f.txt\\\"\n"
  end
  it "should build a smbclient-wrapped command" do
    rm = DeleteFile.new(env,'f.txt')
    expect(rm.smb).to eq "echo \"rm \\\"f.txt\\\"\n\" | smbclient -E -g -A #{AUTHFILE} -p #{PORT} //#{ADDRESS}/#{SHARE} 2>&1"
  end
end
describe CompositeCommand, '#action' do
  it "should return a composite command to navigate and remove file" do
    cd_a = GoToDir.new(env,'a')
    cd_b = GoToDir.new(env,'b')
    cd_current = GoToDir.new(env)
    rm = DeleteFile.new(env,'e.txt')
    cmds = CompositeCommand.new(env)
    cmds << cd_a
    cmds << cd_b
    cmds << cd_current
    cmds << rm
    expect(cmds.action).to eq "cd \\\"a\\\"\ncd \\\"b\\\"\ncd \\\".\\\"\nrm \\\"e.txt\\\"\n"
  end
end

describe CIFSOperator do
  operator = CIFSOperator.new(nil,CIFSUriParser.new,env)
  describe '#goto' do
    it "should return array of commands to navigate to given dir" do
      expect(operator.goto('/a/b/c/d/e/f.txt').map{|c| c.action}).to contain_exactly "cd \\\"b\\\"\n", "cd \\\"c\\\"\n", "cd \\\"d\\\"\n", "cd \\\"e\\\"\n"
    end
  end
  describe '#remove' do
    it "should return array of commands to remove file from a given dir" do
      expect(operator.remove('/a/b/c/d/e/f.txt').map{|c| c.action}).to contain_exactly "cd \\\"b\\\"\n", "cd \\\"c\\\"\n", "cd \\\"d\\\"\n", "cd \\\"e\\\"\n", "rm \\\"f.txt\\\"\n"
    end
  end
end


