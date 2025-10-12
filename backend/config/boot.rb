ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load environment variables from backend/.env in development and test without extra gems
if ENV["RAILS_ENV"] != "production"
  env_path = File.expand_path("../.env", __dir__)
  if File.file?(env_path)
    File.foreach(env_path) do |line|
      next if line.strip.empty? || line.start_with?("#")
      key, val = line.split("=", 2)
      next unless key && val
      key = key.strip
      val = val.strip.gsub(/^"|"$|^'|'$/, "")
      ENV[key] ||= val
    end
  end
end
