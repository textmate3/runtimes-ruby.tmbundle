#!/usr/bin/env ruby
# The scripts against the stand-in rv under fixtures/. Run from anywhere:
#
#   ruby Support/tests/ruby_runtime_tests.rb

require "open3"
require "tempfile"
require "tmpdir"

BIN      = File.expand_path("../bin", __dir__)
STUB_RV  = File.expand_path("fixtures/rv", __dir__)

def run(script, *arguments, installed: [], offline: false, pin: nil, chdir: Dir.pwd)
  state = Tempfile.new("rv-state")
  state.write(installed.join("\n") + "\n")
  state.close
  environment = { "RUNTIMES_RV" => STUB_RV, "RV_STUB_STATE" => state.path, "HOME" => Dir.tmpdir }
  environment["RV_STUB_OFFLINE"] = "1" if offline
  environment["RV_STUB_PIN"] = pin if pin
  output, status = Open3.capture2(environment, File.join(BIN, script), *arguments, chdir: chdir)
  [output.lines.map(&:strip), status.exitstatus, File.read(state.path).split("\n")]
ensure
  state&.unlink
end

$failures = 0

def check(description)
  passed = yield
  puts "#{passed ? "ok" : "FAIL"} #{description}"
  $failures += 1 unless passed
rescue StandardError => error
  puts "FAIL #{description}: #{error.class} #{error.message}"
  $failures += 1
end

check "the pinned version already installed is answered without installing" do
  lines, status, installed = run("ruby_runtime", "4.0.6", installed: %w[3.4.9 4.0.6])
  lines == ["ruby /stub/rubies/ruby-4.0.6"] && status == 0 && installed == %w[3.4.9 4.0.6]
end

check "a missing pinned version is installed, and said so" do
  lines, status, installed = run("ruby_runtime", "4.0.6", installed: %w[3.4.9])
  lines == ["installed 4.0.6 /stub/rubies/ruby-4.0.6", "ruby /stub/rubies/ruby-4.0.6"] && status == 0 && installed.include?("4.0.6")
end

check "a near miss is not the pinned version, so the pinned one is installed alongside" do
  lines, _, installed = run("ruby_runtime", "4.0.6", installed: %w[4.0.5])
  lines.last == "ruby /stub/rubies/ruby-4.0.6" && installed == %w[4.0.5 4.0.6]
end

check "offline, the newest of the major series stands in with a reason" do
  lines, status, = run("ruby_runtime", "4.0.6", installed: %w[3.4.9 4.0.5 4.1.0], offline: true)
  lines.size == 1 && lines[0].start_with?("fallback /stub/rubies/ruby-4.1.0 Ruby 4.0.6 could not be installed") && status == 0
end

check "offline with nothing of the series is an error" do
  lines, status, = run("ruby_runtime", "4.0.6", installed: %w[3.4.9], offline: true)
  lines == ["error Ruby 4.0.6 could not be installed and no Ruby 4 is on this machine"] && status == 1
end

check "no version asked for is an error" do
  lines, status, = run("ruby_runtime")
  lines.first.start_with?("error") && status == 2
end

check "a project's pin resolves to its Ruby" do
  Dir.mktmpdir do |project|
    lines, status, = run("project_ruby", project, installed: %w[3.4.9 4.0.6], pin: "3.4.9")
    lines == ["ruby /stub/rubies/ruby-3.4.9"] && status == 0
  end
end

check "a project's pin to a Ruby that is not installed is reported as missing" do
  Dir.mktmpdir do |project|
    lines, = run("project_ruby", project, installed: %w[4.0.6], pin: "3.3.0")
    lines == ["missing 3.3.0"]
  end
end

check "a project without a pin says so" do
  Dir.mktmpdir do |project|
    lines, = run("project_ruby", project, installed: %w[4.0.6])
    lines == ["none"]
  end
end

puts
puts $failures.zero? ? "all passed" : "#{$failures} failed"
exit $failures.zero? ? 0 : 1
