#!/usr/bin/env ruby

require 'yaml'

pattfile = ARGV.first || ''

unless File.file?(pattfile)
  puts "Please give me one pattern file as argument."
  exit -1
end

header = ''
eohmarker = '=' * 42
File.read(pattfile).each_line do |line|
  if line =~ /\\patterns|#{eohmarker}/
    break
  end

  line.gsub!(/^% /, '')
  line.gsub!(/%/, '')
  header += line
end

puts header
begin
  metadata = YAML::load(header)
rescue Psych::SyntaxError
  puts "There was an error parsing the metadata."
  exit -2
end
puts metadata.inspect
