xml.SOAP(:Envelope, "xmlns:SOAP" => "http://schemas.xmlsoap.org/soap/envelope/", "xmlns:filebroker" => "http://nordea.com/filebroker") do
	xml.SOAP :Body do
		xml.filebroker :ListResponse do
			xml.filebroker :List do
				list.each { |x|
					xml.filebroker :File do
						xml.filebroker(:Name, x['name'])
						xml.filebroker(:Size, x['size'])
						xml.filebroker(:ModificationTime, x['mtime'])
					end
				}
			end
		end
	end
end
