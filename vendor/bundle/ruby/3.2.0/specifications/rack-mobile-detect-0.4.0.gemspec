# -*- encoding: utf-8 -*-
# stub: rack-mobile-detect 0.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rack-mobile-detect".freeze
  s.version = "0.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Tom Alison".freeze]
  s.date = "2012-06-07"
  s.description = "Rack::MobileDetect detects mobile devices and adds an\n    X_MOBILE_DEVICE header to the request if a mobile device is detected. Specific\n    devices can be targeted with custom Regexps and redirect support is available.".freeze
  s.email = "accounts@majortom.fastmail.us".freeze
  s.extra_rdoc_files = ["LICENSE".freeze, "README.md".freeze, "TODO".freeze]
  s.files = ["LICENSE".freeze, "README.md".freeze, "TODO".freeze]
  s.homepage = "http://github.com/talison/rack-mobile-detect".freeze
  s.rubygems_version = "3.4.10".freeze
  s.summary = "Rack middleware for ruby webapps to detect mobile devices.".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 3

  s.add_development_dependency(%q<shoulda>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<rack>.freeze, [">= 0"])
end
