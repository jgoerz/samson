# frozen_string_literal: true
require 'vault'

module Samson
  module Secrets
    class BackendError < StandardError
    end

    class HashicorpVaultBackend
      # / means diretory in vault and we want to keep all the ids in the same folder
      DIRECTORY_SEPARATOR = "/"
      ID_SEGMENTS = 4
      IMPORTANT_COLUMNS = [:visible, :deprecated_at, :comment, :creator_id, :updater_id].freeze

      class << self
        def read(id)
          return unless id
          result = vault_action(:read, vault_path(id, :encode))
          return if !result || result.data[:vault].nil?

          result = result.to_h
          result = result.merge(result.delete(:data))
          result[:value] = result.delete(:vault)
          result
        end

        def read_multi(ids)
          # will be used inside the threads and can lead to errors when not preloaded
          # reproducible by running a single test like hashicorp_vault_backend_test.rb -n '/filter_keys_by_value/'
          Samson::Secrets::Manager.name

          found = {}
          Samson::Parallelizer.map(ids, db: true) do |id|
            begin
              if value = read(id)
                found[id] = value
              end
            rescue # deploy group has no vault server or deploy group no longer exists
              nil
            end
          end
          found
        end

        def write(id, data)
          user_id = data.fetch(:user_id)
          current = read(id)
          creator_id = (current && current[:creator_id]) || user_id
          data = data.merge(creator_id: creator_id, updater_id: user_id)

          begin
            deep_write(id, data)
          rescue
            revert(id, current)
            raise
          end
        end

        def delete(id)
          vault_action(:delete, vault_path(id, :encode))
        end

        def ids
          ids = vault_action(:list_recursive, "")
          ids.uniq! # we read from multiple backends that might have the same ids
          ids.map! { |secret_path| vault_path(secret_path, :decode) }
        end

        def deploy_groups
          DeployGroup.where.not(vault_server_id: nil)
        end

        private

        def revert(id, current)
          if current
            deep_write(id, current)
          else
            delete(id)
          end
        rescue
          nil # ignore errors in here
        end

        # write to the backend ... but exclude metadata from a read/write update cycle
        def deep_write(id, data)
          important = {vault: data.fetch(:value)}.merge(data.slice(*IMPORTANT_COLUMNS))
          vault_action(:write, vault_path(id, :encode), important)
        end

        def vault_action(method, path, *args)
          vault_client.public_send(method, path, *args)
        rescue Vault::HTTPConnectionError => e
          raise Samson::Secrets::BackendError, "Error talking to vault backend: #{e.message}"
        end

        def vault_client
          Samson::Secrets::VaultClient.client
        end

        # id is the last element and should not include directories
        def vault_path(id, direction)
          parts = id.split(DIRECTORY_SEPARATOR, ID_SEGMENTS)
          raise ActiveRecord::RecordNotFound, "Invalid id #{id.inspect}" unless last = parts[ID_SEGMENTS - 1]
          convert_path!(last, direction)
          parts.join(DIRECTORY_SEPARATOR)
        end

        # convert from/to escaped characters
        def convert_path!(string, direction)
          case direction
          when :encode then string.gsub!(DIRECTORY_SEPARATOR, "%2F")
          when :decode then string.gsub!("%2F", DIRECTORY_SEPARATOR)
          else raise ArgumentError, "direction is required"
          end
          string
        end
      end
    end
  end
end
