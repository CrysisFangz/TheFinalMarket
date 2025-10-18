# -*- encoding: utf-8 -*-
# stub: turbo_boost-streams 0.1.11 ruby lib

Gem::Specification.new do |s|
  s.name = "turbo_boost-streams".freeze
  s.version = "0.1.11"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/hopsoft/turbo_boost-streams/blob/main/CHANGELOG.md", "homepage_uri" => "https://github.com/hopsoft/turbo_boost-streams", "source_code_uri" => "https://github.com/hopsoft/turbo_boost-streams" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Nate Hopkins (hopsoft)".freeze]
  s.date = "2024-02-29"
  s.description = "Take full control of the DOM with Turbo Streams".freeze
  s.email = ["natehop@gmail.com".freeze]
  s.homepage = "https://github.com/hopsoft/turbo_boost-streams".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7".freeze)
  s.rubygems_version = "3.4.10".freeze
  s.summary = "Take full control of the DOM with Turbo Streams".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rails>.freeze, [">= 6.1"])
  s.add_runtime_dependency(%q<turbo-rails>.freeze, [">= 1.1"])
  s.add_development_dependency(%q<capybara>.freeze, [">= 0"])
  s.add_development_dependency(%q<capybara-playwright-driver>.freeze, [">= 0"])
  s.add_development_dependency(%q<foreman>.freeze, [">= 0"])
  s.add_development_dependency(%q<importmap-rails>.freeze, [">= 0"])
  s.add_development_dependency(%q<magic_frozen_string_literal>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest-reporters>.freeze, [">= 0"])
  s.add_development_dependency(%q<net-smtp>.freeze, [">= 0"])
  s.add_development_dependency(%q<pry-byebug>.freeze, [">= 0"])
  s.add_development_dependency(%q<puma>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rexml>.freeze, [">= 0"])
  s.add_development_dependency(%q<rouge>.freeze, [">= 0"])
  s.add_development_dependency(%q<runfile>.freeze, [">= 0"])
  s.add_development_dependency(%q<sprockets-rails>.freeze, [">= 0"])
  s.add_development_dependency(%q<sqlite3>.freeze, [">= 0"])
  s.add_development_dependency(%q<standardrb>.freeze, [">= 0"])
  s.add_development_dependency(%q<tailwindcss-rails>.freeze, [">= 0"])
  s.add_development_dependency(%q<web-console>.freeze, [">= 0"])
  s.add_development_dependency(%q<webdrivers>.freeze, [">= 0"])
end
