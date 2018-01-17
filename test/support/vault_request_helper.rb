# frozen_string_literal: true
module VaultRequestHelper
  def self.included(base)
    base.before do
      Samson::Secrets::VaultClient.class_eval { @client = nil } # bust client cache so we build a new one each time
      deploy_groups(:pod2).update_column(:vault_server_id, create_vault_server.id)
    end
  end

  def assert_vault_request(method, path, options = {}, &block)
    options[:to_return] = {
      headers: options.delete(:headers) || {content_type: 'application/json'}, # does not parse json without
      body: options.delete(:body) || "{}", # errors need a basic response too
      status: options.delete(:status) || 200
    }
    assert_request(method, "http://vault-land.com/v1/secret/apps/#{path}", options, &block)
  end
end
