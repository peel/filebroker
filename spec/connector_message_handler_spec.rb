require 'rspec'
require 'rspec-parameterized'
require_relative '../lib/common'
require_relative '../lib/connector_message_handler'

describe ConnectorMessageHandler, '#handle_message' do
  address = 'cifs-01.nas-01-int.pld2.root4.net'
  path = '/lorem/ipsum'
  file = 'dolor'
  where(:message, :response) do
    [
      ['NT_STATUS_LOGON_FAILURE',Connector::AuthenticationFailed],
      ['NT_STATUS_ACCESS_DENIED',Connector::AuthenticationFailed],
      ['NT_STATUS_UNSUCCESSFUL',Connector::HostUnreachable],
      ['NT_STATUS_HOST_UNREACHABLE',Connector::HostUnreachable],
      ['NT_STATUS_BAD_NETWORK_NAME',Connector::BadNetworkName],
      ['NT_STATUS_CONNECTION_REFUSED',Connector::ConnectionRefused],
      ["Receiving SMB: Server #{address} stopped responding",Connector::ConnectionRefused],
      ['NT_STATUS_NETWORK_UNREACHABLE',Connector::NetworkUnreachable],
      ['NT_STATUS_OBJECT_PATH_NOT_FOUND',Connector::NoSuchFileOrDirectory],
      ['NT_STATUS_OBJECT_NAME_NOT_FOUND',Connector::NoSuchFileOrDirectory],
      ['NT_STATUS_NO_SUCH_FILE',Connector::NoSuchFileOrDirectory],
      ['NT_STATUS_CANNOT_DELETE',Connector::PermissionDenied],
      ['NT_STATUS_ACCOUNT_DISABLED',Connector::PermissionDenied],
      ['NT_STATUS_ACCOUNT_LOCKED',Connector::PermissionDenied],
      ['session setup failed',Connector::PermissionDenied],
      ['not a directory',Connector::PermissionDenied]
    ]
  end

  with_them do
     it 'given status message of smb connection failure should retry action on a file ' do
      handler = ConnectorMessageHandler.new(address,path,file)
      expect{handler.handle_message(message)}.to raise_error(response)
    end
  end

  it 'should raise specific error for an exception' do
    handler = ConnectorMessageHandler.new(address,path,file)
    expect{handler.retry(nil,handler.action)}.to raise_error(Connector::ConnectionRefused)
  end
end