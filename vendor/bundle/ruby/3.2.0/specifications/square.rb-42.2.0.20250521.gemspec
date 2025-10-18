# -*- encoding: utf-8 -*-
# stub: square.rb 42.2.0.20250521 ruby lib

Gem::Specification.new do |s|
  s.name = "square.rb".freeze
  s.version = "42.2.0.20250521"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Square Developer Platform".freeze]
  s.date = "2025-05-21"
  s.description = "".freeze
  s.email = ["developers@squareup.com".freeze]
  s.homepage = "https://squareup.com/developers".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.6".freeze)
  s.rubygems_version = "3.4.10".freeze
  s.summary = "square".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<apimatic_core_interfaces>.freeze, ["~> 0.2.1"])
  s.add_runtime_dependency(%q<apimatic_core>.freeze, ["~> 0.3.11"])
  s.add_runtime_dependency(%q<apimatic_faraday_client_adapter>.freeze, ["~> 0.1.4"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.24.0"])
  s.add_development_dependency(%q<minitest-proveit>.freeze, ["~> 1.0"])
end
