class FilenameParser
  def is_an_encryption(filename)
    filename.gsub(/\.(gpg|GPG|pgp|PGP)/, '')
  end
  def encrypted_filename_variants(file)
    suffixes = %w(.gpg .GPG .pgp .PGP)
    files = [file].product(suffixes).map{|filename,suffix| filename+suffix}
    files << file
  end
  def file_and_encrypted(list, filename)
    list & encrypted_filename_variants(filename)
  end
  def filter_out_file_and_encrypted(list,file)
    file_and_encrypted(list, file).each { |name| list.delete(name) }
    list
  end
end

class CIFSUriParser
  SHARE_IDX=1
  FILENAME_IDX=-1
  def remove_empty(arr)
    arr.reject(&:empty?)
  end
  def names(uri,from,to=uri.length)
    arr = uri.split('/')[from..to]
    remove_empty(arr)
  end
  def name(uri,idx)
    names(uri,idx,idx).first
  end
  def share(uri)
    name(uri,SHARE_IDX)
  end
  def file(uri)
    name(uri,FILENAME_IDX)
  end
  def directories(uri)
    names(uri,SHARE_IDX+1,FILENAME_IDX-1)
  end
end

class CIFSCommands
  attr_accessor :uri_parser
  def initialize(uri_parser)
    @uri_parser=uri_parser
  end
  def go_to_file(uri)
    directories = @uri_parser.directories(uri)
    directories.map{|dir| "cd \\\"#{dir}\\\""}.join("\n")+"\n"
  end
  def remove_file_from_current_dir(filename)
    "rm \\\"#{filename}\\\"\n"
  end
  def remove_file_from_dir(path_w_filename)
    filename=@uri_parser.file(path_w_filename)
    cd = go_to_file(path_w_filename)
    rm = remove_file_from_current_dir(filename)
    cd+rm
  end

  def connect_and_remove(uri, authfile, port, address, share)
    "echo \"#{remove_file_from_dir(uri)}\" | smbclient -E -g -A #{authfile} -p #{port} //#{address}/#{share} 2>&1"
  end
end