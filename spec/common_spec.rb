require 'rspec'
require './lib/common'

describe Connector::CIFS, '#getcolumn' do
  it "returns filename for large files" do
    lines=['  fbdummy.bin                         A 195991527424  Fri Nov 14 01:19:30 2014']
    cifs = Connector::CIFS.new
    expect(cifs.list_items(lines).first['name']).to eq 'fbdummy.bin'
  end

  it "returns filename for files with spaces in names" do
    lines=['  R0 MN 20141022 211940.csv          A     1555  Wed Oct 22 21:30:11 2014']
    cifs = Connector::CIFS.new
    expect(cifs.list_items(lines).first['name']).to eq 'R0 MN 20141022 211940.csv'
  end

  it "returns filename for files on shares NOT adding 'A' column" do
    lines=['  Przelewy_Przyszle_przelewy_zdefiniowane_z_harmonogramem_T24_20141115_115348_1_1.TXT           12742  Sat Nov 15 11:53:48 2014']
    cifs = Connector::CIFS.new
    expect(cifs.list_items(lines).first['name']).to eq 'Przelewy_Przyszle_przelewy_zdefiniowane_z_harmonogramem_T24_20141115_115348_1_1.TXT'
  end

  it "returns filename for files with long names and spaces adding 'A' column" do
    lines=['  R0_MN_20141022_211940213123123312313248923489234.csv          A     1555  Wed Oct 22 21:30:11 2014']
    cifs = Connector::CIFS.new
    expect(cifs.list_items(lines).first['name']).to eq 'R0_MN_20141022_211940213123123312313248923489234.csv'
  end

end
