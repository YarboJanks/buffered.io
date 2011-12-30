#!/usr/bin/env ruby

#require 'pathname'
#require 'fileutils'
Dir.chdir('source/_posts') do
  lines = `grep "^date: " *.markdown`
  lines.split("\n").grep(/[0-9]{4}. /).each {|line|
    file, _, date, *rest = line.split(":")
    date = date.split(" ").first.gsub("/", "-")
    target_file = String.new(file)
    target_file[0, 6] = date + "-"
    File.rename(file, target_file)
  }
end
