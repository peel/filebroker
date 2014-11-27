class CIFSConfig
  attr_reader :address,:port,:share,:authfile
  def initialize(address,port,share,authfile)
    @address=address
    @port=port
    @share=share
    @authfile=authfile
  end
end
