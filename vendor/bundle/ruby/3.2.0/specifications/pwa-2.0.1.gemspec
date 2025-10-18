# -*- encoding: utf-8 -*-
# stub: pwa 2.0.1 ruby lib

Gem::Specification.new do |s|
  s.name = "pwa".freeze
  s.version = "2.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jonas H\u00FCbotter".freeze]
  s.date = "2018-01-26"
  s.description = "Progressive Web Apps for Rails".freeze
  s.email = "me@jonhue.me".freeze
  s.homepage = "https://github.com/jonhue/pwa".freeze
  s.licenses = ["MIT".freeze]
  s.post_install_message = "**Thank you for installing Progressive Web Apps for Rails!**\n\n\nThere are two more steps to take:\n\n1) Run `rails g pwa:install` and `rails g pwa:install -n \"Application Name\"`\n2) Mount engine in `config/routes.rb`:\n\n    mount Pwa::Engine, at: ''\n\n\nLearn more at https://github.com/jonhue/pwa\n".freeze
  s.required_ruby_version = Gem::Requirement.new(">= 2.3".freeze)
  s.rubygems_version = "3.4.10".freeze
  s.summary = "Progressive Web Apps for Rails".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<railties>.freeze, [">= 5.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.7"])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 0.52"])
end
