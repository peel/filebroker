require 'rspec'
require_relative '../lib/cifs/filename_parser'

describe FilenameParser, '#is_an_encryption' do
  it "checks if file is encrypted version of given filename" do
    files = ['gpgloremips.gpg','gpg lorem ips.gpg','GPGloremips.GPG','GPG lorem ips.GPG','pgploremips.pgp', 'pgp lorem ips.pgp','PGPloremips.PGP','PGP lorem ips.PGP']
    expected = ['gpgloremips','gpg lorem ips','GPGloremips','GPG lorem ips','pgploremips', 'pgp lorem ips','PGPloremips','PGP lorem ips']
    parser = FilenameParser.new
    expect(files.map{|file| parser.is_an_encryption(file)}).to eq expected
  end
end

describe FilenameParser, '#encrypted_filename_variants' do
  it "returns list of all variations of a filename" do
    expected = ['loremips.gpg','loremips.GPG','loremips.pgp','loremips.PGP','loremips']
    parser = FilenameParser.new
    expect(parser.encrypted_filename_variants('loremips')).to eq expected
  end
end

describe FilenameParser, '#file_and_encrypted' do
  it "returns list of all variations of a filename" do
    source = ['lorem ips','ipsumdolor.pgp','ipsumdolor.gpg','ipsumdolor','ipsumdolor.PGP','loremips.gpg','loremips.GPG','loremips.pgp','loremips.PGP','loremips']
    expected = ['loremips.gpg','loremips.GPG','loremips.pgp','loremips.PGP','loremips']
    parser = FilenameParser.new
    expect(parser.file_and_encrypted(source,'loremips')).to eq expected
    parser.file_and_encrypted(source,'loremips').each{puts}
  end
end

describe FilenameParser, '#filter_out_file_and_encrypted' do
  it "given a filename and a list returns list with filtered out filename and encrypted copies" do
    source = ['lorem ips','ipsumdolor.pgp','ipsumdolor.gpg','ipsumdolor','ipsumdolor.PGP','loremips.gpg','loremips.GPG','loremips.pgp','loremips.PGP','loremips']
    expected = ['lorem ips','ipsumdolor.pgp','ipsumdolor.gpg','ipsumdolor','ipsumdolor.PGP']
    parser = FilenameParser.new
    expect(parser.filter_out_file_and_encrypted(source,'loremips')).to eq expected
  end
end

