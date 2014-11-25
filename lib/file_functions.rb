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
