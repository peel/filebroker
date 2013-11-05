xml.SOAP(:Envelope, "xmlns:SOAP" => "http://schemas.xmlsoap.org/soap/envelope/", "xmlns:filebroker" => "http://nordea.com/filebroker") do
  xml.SOAP :Body do
    xml.filebroker :ServiceStatusResponse do
      xml.filebroker(:LastTransferTime, time)
    end
  end
end
