# -*- encoding: utf-8 -*-
# stub: heap-profiler 0.7.0 ruby lib
# stub: ext/heap_profiler/extconf.rb

Gem::Specification.new do |s|
  s.name = "heap-profiler".freeze
  s.version = "0.7.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org/", "homepage_uri" => "https://github.com/Shopify/heap-profiler", "source_code_uri" => "https://github.com/Shopify/heap-profiler" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jean Boussier".freeze]
  s.bindir = "exe".freeze
  s.date = "2023-02-27"
  s.description = "Make several heap dumps and summarize allocated, retained memory".freeze
  s.email = ["jean.boussier@gmail.com".freeze]
  s.executables = ["heap-profiler".freeze]
  s.extensions = ["ext/heap_profiler/extconf.rb".freeze]
  s.files = ["exe/heap-profiler".freeze, "ext/heap_profiler/extconf.rb".freeze]
  s.homepage = "https://github.com/Shopify/heap-profiler".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.4.10".freeze
  s.summary = "Ruby heap profiling tool".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version
end
