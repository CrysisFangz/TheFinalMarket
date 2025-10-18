# -*- encoding: utf-8 -*-
# stub: mission_control-jobs 0.6.0 ruby lib

Gem::Specification.new do |s|
  s.name = "mission_control-jobs".freeze
  s.version = "0.6.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "homepage_uri" => "https://github.com/rails/mission_control-jobs", "source_code_uri" => "https://github.com/rails/mission_control-jobs" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jorge Manrubia".freeze]
  s.date = "2024-11-15"
  s.email = ["jorge@hey.com".freeze]
  s.homepage = "https://github.com/rails/mission_control-jobs".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.10".freeze
  s.summary = "Operational controls for Active Job".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 7.1"])
  s.add_runtime_dependency(%q<activejob>.freeze, [">= 7.1"])
  s.add_runtime_dependency(%q<actionpack>.freeze, [">= 7.1"])
  s.add_runtime_dependency(%q<actioncable>.freeze, [">= 7.1"])
  s.add_runtime_dependency(%q<railties>.freeze, [">= 7.1"])
  s.add_runtime_dependency(%q<importmap-rails>.freeze, [">= 1.2.1"])
  s.add_runtime_dependency(%q<turbo-rails>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<stimulus-rails>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<irb>.freeze, ["~> 1.13"])
  s.add_development_dependency(%q<resque>.freeze, [">= 0"])
  s.add_development_dependency(%q<solid_queue>.freeze, ["~> 1.0.1"])
  s.add_development_dependency(%q<selenium-webdriver>.freeze, [">= 0"])
  s.add_development_dependency(%q<resque-pause>.freeze, [">= 0"])
  s.add_development_dependency(%q<mocha>.freeze, [">= 0"])
  s.add_development_dependency(%q<debug>.freeze, [">= 0"])
  s.add_development_dependency(%q<redis>.freeze, [">= 0"])
  s.add_development_dependency(%q<redis-namespace>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.52.0"])
  s.add_development_dependency(%q<rubocop-performance>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubocop-rails-omakase>.freeze, [">= 0"])
  s.add_development_dependency(%q<better_html>.freeze, [">= 0"])
  s.add_development_dependency(%q<propshaft>.freeze, [">= 0"])
  s.add_development_dependency(%q<sqlite3>.freeze, [">= 0"])
  s.add_development_dependency(%q<puma>.freeze, [">= 0"])
end
