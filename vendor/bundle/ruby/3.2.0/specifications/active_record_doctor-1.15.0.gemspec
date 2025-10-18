# -*- encoding: utf-8 -*-
# stub: active_record_doctor 1.15.0 ruby lib

Gem::Specification.new do |s|
  s.name = "active_record_doctor".freeze
  s.version = "1.15.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Greg Navis".freeze]
  s.date = "2024-08-28"
  s.email = ["contact@gregnavis.com".freeze]
  s.homepage = "https://github.com/gregnavis/active_record_doctor".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.1.0".freeze)
  s.rubygems_version = "3.4.10".freeze
  s.summary = "Identify database issues before they hit production.".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 4.2.0"])
  s.add_development_dependency(%q<minitest-fork_executor>.freeze, ["~> 1.0.2"])
  s.add_development_dependency(%q<mysql2>.freeze, ["~> 0.5.3"])
  s.add_development_dependency(%q<pg>.freeze, ["~> 1.5.6"])
  s.add_development_dependency(%q<railties>.freeze, [">= 4.2.0"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 12.3.3"])
  s.add_development_dependency(%q<transient_record>.freeze, ["~> 2.0.0"])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.57.1"])
end
