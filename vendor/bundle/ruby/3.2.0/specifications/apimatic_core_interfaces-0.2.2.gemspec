# -*- encoding: utf-8 -*-
# stub: apimatic_core_interfaces 0.2.2 ruby lib

Gem::Specification.new do |s|
  s.name = "apimatic_core_interfaces".freeze
  s.version = "0.2.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["APIMatic Ltd.".freeze]
  s.date = "2025-08-12"
  s.description = "This project contains the abstract layer for APIMatic's core library. The purpose of creating interfaces is to separate out the functionalities needed by APIMatic's core library module. The goal is to support scalability and feature enhancement of the core library and the SDKs along with avoiding any breaking changes by reducing tight coupling between modules through the introduction of interfaces.".freeze
  s.email = "support@apimatic.io".freeze
  s.homepage = "https://apimatic.io".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.6".freeze)
  s.rubygems_version = "3.4.10".freeze
  s.summary = "An abstract layer of the functionalities provided by apimatic-core, faraday-client-adapter and APIMatic SDKs.".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version
end
