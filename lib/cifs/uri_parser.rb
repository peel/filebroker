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
