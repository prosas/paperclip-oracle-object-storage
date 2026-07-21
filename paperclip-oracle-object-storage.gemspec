# frozen_string_literal: true

require_relative "lib/paperclip/storage/oracle_object_storage/version"

Gem::Specification.new do |spec|
  spec.name = "paperclip-oracle-object-storage"
  spec.version = Paperclip::Storage::OracleObjectStorage::VERSION
  spec.authors = ["Luiz Filipe"]
  spec.email = ["luiz.neves@prosas.com.br", "luizfilipeneves@gmail.com"]

  spec.summary = "Paperclip storage lib to save to Oracle Object Storage"
  spec.description = "Paperclip storage lib to save to Oracle Object Storage"
  spec.homepage = "https://github.com/prosas/paperclip-oracle-object-storage"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/prosas/paperclip-oracle-object-storage"
  spec.metadata["changelog_uri"] = "https://github.com/prosas/paperclip-oracle-object-storage/CHANGELOG.md"

  spec.require_paths = ["lib"]

  gem.add_dependency 'oci', '~> 2.23'
end
