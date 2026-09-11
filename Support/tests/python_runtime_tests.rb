#!/usr/bin/env ruby
# python_runtime against the stand-in uv under fixtures/. Run from anywhere:
#
#   ruby Support/tests/python_runtime_tests.rb

require "open3"
require "tempfile"
require "tmpdir"

BIN     = File.expand_path("../bin", __dir__)
STUB_UV = File.expand_path("fixtures/uv", __dir__)

def run(*arguments, installed: [], offline: false, unmanaged: false)
  state = Tempfile.new("uv-state")
  state.write(installed.join("\n") + "\n")
  state.close
  environment = { "RUNTIMES_UV" => STUB_UV, "UV_STUB_STATE" => state.path, "HOME" => Dir.tmpdir }
  environment["UV_STUB_OFFLINE"] = "1" if offline
  environment["UV_STUB_UNMANAGED"] = "1" if unmanaged
  output, status = Open3.capture2(environment, File.join(BIN, "python_runtime"), *arguments)
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

check "a version already installed is answered without installing" do
  lines, status, installed = run("3.13.15", installed: %w[3.12.8 3.13.15])
  lines == ["python /stub/pythons/cpython-3.13.15-macos-aarch64-none/bin/python3"] &&
    status == 0 && installed == %w[3.12.8 3.13.15]
end

check "a version that is missing is installed and then answered" do
  lines, status, installed = run("3.13", installed: %w[3.12.8])
  lines == [
    "installed 3.13 /stub/pythons/cpython-3.13.15-macos-aarch64-none/bin/python3",
    "python /stub/pythons/cpython-3.13.15-macos-aarch64-none/bin/python3",
  ] && status == 0 && installed == %w[3.12.8 3.13.15]
end

check "with no network the newest managed Python stands in and says why" do
  lines, status, = run("3.13", installed: %w[3.12.8], offline: true)
  lines.size == 1 && status == 0 &&
    lines.first.start_with?("fallback /stub/pythons/cpython-3.12.8-macos-aarch64-none/bin/python3 ") &&
    lines.first.include?("could not be installed")
end

check "with no network and nothing managed it is an error rather than a guess" do
  lines, status, = run("3.13", installed: [], offline: true)
  lines.size == 1 && status == 1 && lines.first.start_with?("error ")
end

check "the system Python is never answered with, even when uv can see it" do
  lines, status, = run("3.13", installed: %w[3.13.15], unmanaged: true)
  lines == ["python /stub/pythons/cpython-3.13.15-macos-aarch64-none/bin/python3"] && status == 0
end

check "the system Python is not reached for as a fallback either" do
  lines, status, = run("3.13", installed: [], offline: true, unmanaged: true)
  status == 1 && lines.none? { it.include?("/usr/bin/python3") }
end

check "no version asked for is a usage error" do
  lines, status, = run
  status == 2 && lines.first.start_with?("error python_runtime needs the version")
end

check "a missing uv is an error that names the reason" do
  state = Tempfile.new("uv-state")
  state.close
  output, status = Open3.capture2(
    { "RUNTIMES_UV" => "/nonexistent/uv", "UV_STUB_STATE" => state.path, "HOME" => Dir.tmpdir },
    File.join(BIN, "python_runtime"), "3.13"
  )
  state.unlink
  status.exitstatus == 1 && output.include?("uv is missing")
end

puts $failures.zero? ? "\nall good" : "\n#{$failures} failed"
exit($failures.zero? ? 0 : 1)
