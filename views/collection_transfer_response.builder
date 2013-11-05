xml.SOAP(:Envelope, "xmlns:SOAP" => "http://schemas.xmlsoap.org/soap/envelope/", "xmlns:filebroker" => "http://nordea.com/filebroker") do
  xml.SOAP :Body do
    xml.filebroker :CollectionTransferResponse do
      xml.filebroker(:TransferID, transfer_id)
    end
  end
end