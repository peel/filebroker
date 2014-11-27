require 'rspec'
require './lib/file_functions'

describe CIFSCommands do
navigator=CIFSCommands.new(CIFSUriParser.new)

  describe '#go_to_file' do
    it "should return command to navigate to given dir" do
      expect(navigator.go_to_file('/a/b/c/d/e/f.txt')).to eq "cd \\\"b\\\"\ncd \\\"c\\\"\ncd \\\"d\\\"\ncd \\\"e\\\"\n"
    end
  end
  describe '#remove_file_from_current_dir' do
    it "should return command to navigate to given dir" do
      expect(navigator.remove_file_from_current_dir('f.txt')).to eq "rm \\\"f.txt\\\"\n"
    end
  end
  describe '#remove_file_from_dir' do
    it "should return command to navigate to given dir" do
      expect(navigator.remove_file_from_dir('/a/b/c/d/e/f.txt')).to eq "cd \\\"b\\\"\ncd \\\"c\\\"\ncd \\\"d\\\"\ncd \\\"e\\\"\nrm \\\"f.txt\\\"\n"
    end
  end
  describe '#connect_and_remove_file' do
    it "should return command to navigate to given dir" do
      expect(navigator.connect_and_remove('/a/b/c/d/e/f.txt','/tmp/authfile',445,'cifs-01.nas-01-ext.pld2.root4.net','fes-nemis')).to eq "echo \"cd \\\"b\\\"\ncd \\\"c\\\"\ncd \\\"d\\\"\ncd \\\"e\\\"\nrm \\\"f.txt\\\"\n\" | smbclient -E -g -A /tmp/authfile -p 445 //cifs-01.nas-01-ext.pld2.root4.net/fes-nemis 2>&1"
    end
  end
end


