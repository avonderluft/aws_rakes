# frozen_string_literal: true

require 'awesome_print'
require 'colorize'
require 'diffy'
require 'fileutils'
require 'yaml'
require_relative 'aws_common'

module AwsSetup
  include AwsCommon
  def setup(cached)
    if cli.empty?
      puts 'AWS CLI is not found.  Ensure that it is installed, and in your path.  Exiting.'.red
      exit
    end
    Aws.use_bundled_cert!
    FileUtils.mkdir_p CACHE_PATH
    return if cached

    reset_mfa unless mfa_set?
  end

  def mfa_set?
    system "#{cli} ec2 --output text describe-internet-gateways &>/dev/null"
  end

  def reset_mfa
    puts 'Setting new MFA session...'.light_green
    if ENV['USER'].include? '.'
      first, last = ENV['USER'].split('.')
      aws_user = first[0] + last
    else
      aws_user = ENV['USER']
    end
    print "Enter AWS username (#{aws_user}): ".green
    input = STDIN.gets.chomp
    aws_user = input unless input.empty?
    print 'Enter 6 digit MFA token: '.green
    aws_token = STDIN.gets.chomp
    mfa_cmd = "#{File.join(File.dirname(__FILE__), '../bin/aws_mfa_set.sh')} -u #{aws_user} -t #{aws_token}"
    puts "Executing '#{mfa_cmd}'...".green
    print DIVIDER
    system mfa_cmd
    puts DIVIDER
  end
end
