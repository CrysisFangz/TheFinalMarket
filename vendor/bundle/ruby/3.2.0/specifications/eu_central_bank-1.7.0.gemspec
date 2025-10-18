# -*- encoding: utf-8 -*-
# stub: eu_central_bank 1.7.0 ruby lib

Gem::Specification.new do |s|
  s.name = "eu_central_bank".freeze
  s.version = "1.7.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Shane Emmons".freeze]
  s.date = "2021-11-17"
  s.description = "This gem reads exchange rates from the european central bank website. It uses it to calculates exchange rates. It is compatible with the money gem".freeze
  s.email = ["shane@emmons.io".freeze]
  s.homepage = "https://github.com/RubyMoney/eu_central_bank".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.10".freeze
  s.summary = "Calculates exchange rates based on rates from european central bank. Money gem compatible.".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<nokogiri>.freeze, ["~> 1.9"])
  s.add_runtime_dependency(%q<money>.freeze, ["~> 6.13", ">= 6.13.6"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.5.0"])
end
