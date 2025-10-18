# -*- encoding: utf-8 -*-
# stub: mobile-fu 1.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "mobile-fu".freeze
  s.version = "1.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Brendan Lim".freeze, "Ben Langfeld".freeze]
  s.date = "2017-08-20"
  s.description = "Want to automatically detect mobile devices that access your Rails application? Mobile Fu allows you to do just that. People can access your site from a Palm, Blackberry, iPhone, iPad, Nokia, etc. and it will automatically adjust the format of the request from :html to :mobile.".freeze
  s.email = ["brendangl@gmail.com, ben@langfeld.me".freeze]
  s.homepage = "https://github.com/benlangfeld/mobile-fu".freeze
  s.rubygems_version = "3.4.10".freeze
  s.summary = "Automatically detect mobile requests from mobile devices in your Rails application.".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rails>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<rack-mobile-detect>.freeze, [">= 0"])
  s.add_development_dependency(%q<mocha>.freeze, [">= 0"])
  s.add_development_dependency(%q<rdoc>.freeze, [">= 0"])
  s.add_development_dependency(%q<httparty>.freeze, [">= 0"])
end
