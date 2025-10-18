# -*- encoding: utf-8 -*-
# stub: grape-entity 1.0.1 ruby lib

Gem::Specification.new do |s|
  s.name = "grape-entity".freeze
  s.version = "1.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["LeFnord".freeze, "Michael Bleigh".freeze]
  s.date = "2024-04-10"
  s.description = "Extracted from Grape, A Ruby framework for rapid API development with great conventions.".freeze
  s.email = ["pscholz.le@gmail.com".freeze, "michael@intridea.com".freeze]
  s.homepage = "https://github.com/ruby-grape/grape-entity".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0".freeze)
  s.rubygems_version = "3.4.10".freeze
  s.summary = "A simple facade for managing the relationship between your model and API.".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 3.0.0"])
  s.add_runtime_dependency(%q<multi_json>.freeze, [">= 1.3.2"])
end
