# frozen_string_literal: true

module Paperclip
  module Storage
    module OracleObjectStorage
      def self.extended(base)
        begin
          require "oci"
        rescue LoadError => e
          raise("#{e.message} (You may need to install the oci gem)")
        end

        base.instance_eval do
          #TODO: Load config by file.
          # if oci_credentials[:config_file]
          #   @config = OCI::ConfigFileLoader.load_config(
          #         oci_credentials[:config_file],
          #         oci_credentials[:profile] || "DEFAULT"
          #       )
          # end
          @config = OCI::Config.new

          @config.user = oci_credentials[:user]
          @config.fingerprint = oci_credentials[:fingerprint]
          @config.tenancy = oci_credentials[:tenancy]
          @config.region = oci_credentials[:region]
          @config.key_file = oci_credentials[:key_file]


          @bucket_name = oci_credentials[:bucket_name]
          @options[:path] = path_option.gsub(/:url/, @options[:url]).sub(/\A:rails_root\/public\/system/, "")
          @options[:url] = @options[:url].inspect if @options[:url].is_a?(Symbol)
        end
      end

      def oci_credentials
        @oci_credentials ||= parse_credentials(@options[:oci_credentials])
      end

      def bucket_name
        @bucket_name
      end

      def namespace
        @namespace ||= begin
          configured = @options[:namespace] || oci_credentials[:namespace]

          return configured if configured.present?

          object_storage_client.get_namespace.data
        end
      end

      def object_storage_client
        # Doc of OCI client: https://docs.oracle.com/en-us/iaas/tools/ruby/2.22.0/OCI/ObjectStorage/ObjectStorageClient.html#put_object_lifecycle_policy-instance_method
        @object_storage_client ||= OCI::ObjectStorage::ObjectStorageClient.new(config: @config)
      end

      def object_name(style = default_style)
        path(style).sub(%r{\A/}, "").unicode_normalize(:nfc).then { |p| I18n.transliterate(p) }
      end

      def exists?(style = default_style)
        return false unless original_filename

        object_storage_client.head_object(
          namespace,
          bucket_name,
          object_name(style)
        )

        true
      rescue OCI::Errors::ServiceError => e
        return false if e.status_code == 404

        raise
      end

      def expiring_url(time = 3600, style = default_style)
        expires_at = Time.now.utc + time

        details =
          OCI::ObjectStorage::Models::CreatePreauthenticatedRequestDetails.new(
            name: "paperclip-#{SecureRandom.hex(8)}",
            object_name: object_name(style),
            access_type: "ObjectRead",
            time_expires: expires_at
          )

        response =
          object_storage_client.create_preauthenticated_request(
            namespace,
            bucket_name,
            details
          )

        endpoint = object_storage_client.endpoint

        "#{endpoint.chomp("/")}#{response.data.access_uri}"
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          begin
            log("saving to Oracle object storage #{path(style)}")
            object_storage_client.put_object(
              object_storage_client.get_namespace.data,
              bucket_name,
              object_name(style),
              File.open(file.path),
              {
                content_type: file.content_type
              }
            )
          rescue => e
            log("error saving to Oracle object storage #{path(style)}")
            raise e
          end
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            log("deleting #{path}")
            object_storage_client.delete_object(
              object_storage_client.get_namespace.data,
              bucket_name,
              object_name
            )
          rescue
            log("error deleting #{path}")
            raise e
          end
        end
        @queued_for_delete = []
      end

      def copy_to_local_file(style, local_dest_path)
        log("copying #{path(style)} to #{local_dest_path}")

        response =
          object_storage_client.get_object(
            namespace,
            bucket_name,
            object_name(style)
          )

        File.binwrite(local_dest_path, response.data)
      rescue OCI::Errors::ServiceError => e
        warn("#{e} - cannot copy #{path(style)}")
        false
      end

      def create_bucket
        details =
          OCI::ObjectStorage::Models::CreateBucketDetails.new(
            name: bucket_name,
            compartment_id: compartment_id
          )

        object_storage_client.create_bucket(
          namespace,
          details
        )
      end

      private

      def compartment_id
        @options[:compartment_id] ||
          oci_credentials[:compartment_id]
      end

      def parse_credentials(creds)
        creds = creds.call(self) if creds.respond_to?(:call)

        case creds
        when File
          load_credentials_from_file(creds.path)
        when String, Pathname
          load_credentials_from_file(creds)
        when Hash
          creds.symbolize_keys
        when NilClass
          {}
        else
          raise ArgumentError,
                "Credentials given are not a path, file, proc, or hash."
        end
      end

      def load_credentials_from_file(path)
        YAML.safe_load(
          ERB.new(File.read(path)).result,
          aliases: true
        ).symbolize_keys
      end
    end
  end
end