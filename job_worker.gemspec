# -*- encoding: utf-8 -*-
require "./lib/job_worker/version"

Gem::Specification.new do |s|
  s.name = "job_worker"
  s.version = JobWorker::VERSION
  #   s.platform = Gem::Platform::RUBY
  s.authors = ["Tijesunimi Peters"]
  s.email = ["tijesunimipeters@gmail.com"]
  s.homepage = "https://github.com/tijesunimi-peters/job_worker"
  s.description = s.summary = %q{Generic job worker for Ruby}

  s.files = `git ls-files`.split("\n")
  s.required_ruby_version = ">= 2.2.2"
  #   s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  #   s.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.license = "MIT"
  s.add_development_dependency "bundler", "~> 0"
  s.add_development_dependency "minitest", "~> 5.0", ">= 5.0.0"
  s.add_development_dependency "rake", "~> 0"
  s.add_development_dependency "redis", "~> 0"
  s.add_development_dependency "pry", "~> 0"
  s.add_development_dependency "fugit", "~> 0"
end
