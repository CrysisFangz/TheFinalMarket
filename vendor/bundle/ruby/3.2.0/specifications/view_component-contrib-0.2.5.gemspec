# -*- encoding: utf-8 -*-
# stub: view_component-contrib 0.2.5 ruby lib

Gem::Specification.new do |s|
  s.name = "view_component-contrib".freeze
  s.version = "0.2.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "http://github.com/palkan/view_component-contrib/issues", "changelog_uri" => "https://github.com/palkan/view_component-contrib/blob/master/CHANGELOG.md", "documentation_uri" => "http://github.com/palkan/view_component-contrib", "homepage_uri" => "http://github.com/palkan/view_component-contrib", "source_code_uri" => "http://github.com/palkan/view_component-contrib" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vladimir Dementyev".freeze]
  s.date = "2025-08-11"
  s.description = "A collection of extensions and developer tools for ViewComponent".freeze
  s.email = ["dementiev.vm@gmail.com".freeze]
  s.homepage = "http://github.com/palkan/view_component-contrib".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7".freeze)
  s.rubygems_version = "3.4.10".freeze
  s.summary = "A collection of extensions and developer tools for ViewComponent".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<view_component>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<ruby-next-core>.freeze, [">= 0.15.0"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 1.15"])
  s.add_development_dependency(%q<capybara>.freeze, [">= 0"])
  s.add_development_dependency(%q<combustion>.freeze, [">= 1.1"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.0"])
  s.add_development_dependency(%q<minitest-focus>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest-reporters>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 13.0"])
end
