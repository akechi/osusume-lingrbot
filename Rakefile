#task :default => [:test]
#
#require 'rake/testtask'
#Rake::TestTask.new(:test) do |t|
#  t.pattern = "spec/*_spec.rb"
#end
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec
