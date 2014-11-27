require 'rspec'
require_relative '../lib/cifs/uri_parser'

describe CIFSUriParser do
  uri = '/aa/bb/cc/dd/ee.txt'
  parser=CIFSUriParser.new
  share_idx=1
  filename_idx=-1

  describe '#remove_empty' do
    it "should return names between given index and last element including last" do
      expect(parser.remove_empty(['aa','','bb'])).to eq ['aa','bb']
    end
  end
  describe '#names' do
    it "should return names between given index and last element including last" do
      expect(parser.names(uri,share_idx)).to eq ['aa','bb','cc','dd','ee.txt']
    end
  end
  describe '#names' do
    it "should return names between given indices including last" do
      expect(parser.names(uri,share_idx,3)).to eq ['aa','bb','cc']
    end
  end
  describe '#names' do
    it "should return names 0th element and -n th" do
      expect(parser.names(uri,filename_idx)).to eq ['ee.txt']
    end
  end
  describe '#names' do
    it "should return names 0th element and -n th" do
      expect(parser.names(uri,filename_idx)).to eq ['ee.txt']
    end
  end
  describe '#name' do
    it "should return name at a given index" do
      expect(parser.name(uri,share_idx)).to eq 'aa'
    end
  end
  describe '#name' do
    it "should return name at a given index when counting backwards" do
      expect(parser.name(uri,filename_idx)).to eq 'ee.txt'
    end
  end
  describe '#share' do
    it "should return name at a given index when counting backwards" do
      expect(parser.share(uri)).to eq 'aa'
    end
  end
  describe '#file' do
    it "should return name at a given index when counting backwards" do
      expect(parser.file(uri)).to eq 'ee.txt'
    end
  end
  describe '#directories' do
    it "should return an array of directories" do
      expect(parser.directories(uri)).to eq ['bb','cc','dd']
    end
  end
end
