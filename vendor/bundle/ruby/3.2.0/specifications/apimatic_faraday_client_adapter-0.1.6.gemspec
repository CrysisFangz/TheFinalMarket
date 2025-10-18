# -*- encoding: utf-8 -*-
# stub: apimatic_faraday_client_adapter 0.1.6 ruby lib

Gem::Specification.new do |s|
  s.name = "apimatic_faraday_client_adapter".freeze
  s.version = "0.1.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["APIMatic Ltd.".freeze]
  s.date = "2025-08-12"
  s.description = "Faraday is a simple, yet elegant, HTTP library. This repository contains the client implementation that uses the requests library for python SDK provided by APIMatic.".freeze
  s.email = "support@apimatic.io".freeze
  s.homepage = "https://apimatic.io".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.6".freeze)
  s.rubygems_version = "3.4.10".freeze
  s.summary = "An adapter for faraday client library consumed by the SDKs generated with APIMatic.".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<apimatic_core_interfaces>.freeze, ["~> 0.2.0"])
  s.add_runtime_dependency(%q<faraday>.freeze, ["~> 2.0", ">= 2.0.1"])
  s.add_runtime_dependency(%q<faraday-follow_redirects>.freeze, ["~> 0.2"])
  s.add_runtime_dependency(%q<faraday-multipart>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<faraday-gzip>.freeze, [">= 1", "< 4"])
  s.add_runtime_dependency(%q<faraday-retry>.freeze, ["~> 2.0"])
  s.add_runtime_dependency(%q<faraday-net_http_persistent>.freeze, ["~> 2.0"])
  s.add_runtime_dependency(%q<certifi>.freeze, ["~> 2018.1", ">= 2018.01.18"])
  s.add_runtime_dependency(%q<faraday-http-cache>.freeze, ["~> 2.2"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.14", ">= 5.14.1"])
  s.add_development_dependency(%q<minitest-proveit>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.21.2"])
  s.add_development_dependency(%q<webrick>.freeze, ["~> 1.3", ">= 1.3.1"])
end
