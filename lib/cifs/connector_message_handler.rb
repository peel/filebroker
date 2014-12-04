require_relative '../common'

class ConnectorMessageHandler
  attr_accessor :address,:path,:file

  def initialize(address,path,file)
    @address=address
    @path=path
    @file=file
  end

  def handle_message(message)
    raise Connector::ConnectionRefused, "connection refused by '#{address}'"          if message =~ /NT_STATUS_CONNECTION_REFUSED/
    raise Connector::ConnectionRefused, "connection refused by '#{address}'"          if message =~ /Receiving SMB: Server \S+ stopped responding/
    raise Connector::AuthenticationFailed, "login refused by '#{address}'"            if message =~ /NT_STATUS_LOGON_FAILURE/
    raise Connector::AuthenticationFailed, "login refused by '#{address}'"            if message =~ /NT_STATUS_ACCESS_DENIED/
    raise Connector::HostUnreachable, "host unreachable '#{address}'"                 if message =~ /NT_STATUS_UNSUCCESSFUL/
    raise Connector::HostUnreachable, "host unreachable '#{address}'"                 if message =~ /NT_STATUS_HOST_UNREACHABLE/
    raise Connector::BadNetworkName, "bad network name '#{address}'"                  if message =~ /NT_STATUS_BAD_NETWORK_NAME/
    raise Connector::NetworkUnreachable, "network unreachable '#{address}'"           if message =~ /NT_STATUS_NETWORK_UNREACHABLE/
    raise Connector::NoSuchFileOrDirectory, "cannot open file or directory '#{file}'"  if message =~ /NT_STATUS_OBJECT_(NAME|PATH)_NOT_FOUND/
    raise Connector::NoSuchFileOrDirectory, "cannot open file or directory '#{file}'"  if message =~ /NT_STATUS_NO_SUCH_FILE/
    raise Connector::PermissionDenied, "permission denied for file '#{file}'"          if message =~ /NT_STATUS_ACCESS_DENIED/
    raise Connector::PermissionDenied, "permission denied for file '#{file}'"          if message =~ /NT_STATUS_CANNOT_DELETE/
    raise Connector::PermissionDenied, "permission denied for file '#{path}'"          if message =~ /NT_STATUS_ACCOUNT_DISABLED/
    raise Connector::PermissionDenied, "permission denied for file '#{path}'"          if message =~ /NT_STATUS_ACCOUNT_LOCKED/
    raise Connector::PermissionDenied, "unknown error '#{message}'"                        if message =~ /session setup failed/
    raise Connector::PermissionDenied, "permission denied for file '#{path}'"          if message =~ /not a directory/
  end
end