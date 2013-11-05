xml.SOAP(:Envelope, "xmlns:SOAP" => "http://schemas.xmlsoap.org/soap/envelope/", "xmlns:filebroker" => "http://nordea.com/filebroker") do
  xml.SOAP :Body do
    xml.filebroker :CollectionStatusResponse do
      xml.filebroker(:TransferID, transfer_id)
      xml.filebroker :TransferStatus do
        xml.filebroker(:Time, status['status_time'])
        xml.filebroker(:StatusID, status['status_id'])
        xml.filebroker(:StatusDescription, status['status_desc'])
      end
      xml.filebroker :Files do
        files.each { |file|
          xml.filebroker :File do
            xml.filebroker(:Name, file['filename'])
            xml.filebroker(:Time, file['status_time'])
            xml.filebroker(:StatusID, file['status_id'])
            xml.filebroker(:StatusType, file['status_type'])
            xml.filebroker(:StatusDescription, file['status_desc'])
          end
        }
      end
    end
  end
end
