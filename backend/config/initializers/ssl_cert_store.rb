# config/initializers/ssl_cert_store.rb
require 'openssl'

store = OpenSSL::X509::Store.new
store.set_default_paths

# Use your Homebrew OpenSSL bundle
file = ENV['SSL_CERT_FILE'].presence || '/opt/homebrew/etc/openssl@3/cert.pem'
dir  = ENV['SSL_CERT_DIR'].presence  || '/opt/homebrew/etc/openssl@3/certs'

store.add_file(file) if file && File.exist?(file)
store.add_path(dir)  if dir && Dir.exist?(dir)

# Ensure no CRL flags are unexpectedly enabled
store.flags = 0

OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:cert_store]  = store
OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:verify_mode] = OpenSSL::SSL::VERIFY_PEER