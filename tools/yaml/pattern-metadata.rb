#!/usr/bin/env ruby

# Validation program for the new YAML headers at the top of TeX hyphenation files.
# Run on an individual file or a directory to get a report of all the errors on the terminal.
# Copyright (c) 2016–2017 Arthur Reutenauer.  MIT licence (https://opensource.org/licenses/MIT)

# TODO Add the optional “source” top-level entry

require 'yaml'
require 'pp'
require 'byebug'

class HeaderValidator
  class WellFormednessError < StandardError # probably not an English word ;-)
  end

  class ValidationError < StandardError
  end

  class InternalError < StandardError
  end

  @@format = {
    title: {
      mandatory: true,
      type: String,
    },
    copyright: {
      mandatory: true,
      type: String,
    },
    authors: {
       mandatory: false,
       type: "...", # TODO Define
    },
    language: {
      mandatory: true,
      type: {
        name: {
          mandatory: true,
          type: String,
        },
        tag: {
          mandatory: true,
          type: String,
        },
      },
    },
    version: {
      mandatory: false,
      type: String,
    },
    notice: {
      mandatory: true,
      type: String,
    },
    licence: {
      mandatory: true,
      one_or_more: true,
      type: "[Knuth only knows]", # TODO Define
    },
    changes: {
      mandatory: false,
      type: String,
    },
    hyphenmins: {
      mandatory: false,
      type: {
        generation: {
          mandatory: false,
          type: {
            left: {
              mandatory: true,
              type: Integer,
            },
            right: {
              mandatory: true,
              type: Integer,
            },
          },
        },
        typesetting: {
          mandatory: false,
          type: {
            left: {
              mandatory: true,
              type: Integer,
            },
            right: {
              mandatory: true,
              type: Integer,
            },
          },
        },
      },
    }
  }

  def initialize
    @errors = { InternalError => [], WellFormednessError => [], ValidationError => [] }
  end

  def parse(filename)
    header = ''
    eohmarker = '=' * 42
    File.read(filename).each_line do |line|
      if line =~ /\\patterns|#{eohmarker}/
        break
      end

      line.gsub!(/^% /, '')
      line.gsub!(/%/, '')
      header += line
    end

    puts header
    begin
      @metadata = YAML::load(header)
    rescue Psych::SyntaxError => err
      raise WellFormednessError.new(err.message)
    end
  end

  def check_mandatory(hash, validator)
    validator.each do |key, validator|
      # byebug if validator[:mandatory] && !hash[key.to_s]
      raise ValidationError.new("Key #{key} missing") if validator[:mandatory] && !hash[key.to_s]
      check_mandatory(hash[key.to_s], validator[:type]) if hash[key.to_s] && validator[:type].respond_to?(:keys)
    end
  end

  def validate(hash, validator)
    hash.each do |key, value|
      # byebug if validator[key.to_sym] == nil
      raise ValidationError.new("Spurious key #{key} found") if validator[key.to_sym] == nil
      validate(value, validator[key.to_sym][:type]) if value.respond_to?(:keys) && !validator[key.to_sym][:one_or_more]
    end
  end

  def run!(pattfile)
    unless File.file?(pattfile)
      raise InternalError.new("Argument “#{pattfile}” is not a file; this shouldn’t have happened.")
    end
    parse(pattfile)
    check_mandatory(@metadata, @@format)
    validate(@metadata, @@format)
    puts @metadata.inspect
  end

  def runfile(filename)
    begin
      run! filename
    rescue InternalError, WellFormednessError, ValidationError => err
      # byebug
      @errors[err.class] << [filename, err.message]
    end
  end

  def main(args)
    while !args.empty?
      arg = args.shift
      if File.file? arg
        runfile(arg)
      elsif Dir.exists? arg
        Dir.foreach(arg) do |filename|
          next if filename == '.' || filename == '..'
          runfile(File.join(arg, filename))
        end
      else
        puts "Argument #{arg} is neither an existing file nor an existing directory; proceeding."
      end
    end

    if @errors.inject(0) { |errs, klass| errs + klass.last.count } > 0
      puts "There were the following errors with some files:"
      summary = []
      @errors.each do |klass, files|
        next if files.count == 0
        files.each do |file|
          filename = file.first
          message = file.last
          summary << "#{filename}: #{klass.name} #{message}"
        end
      end

      puts summary.join "\n"
    end
  end
end

validator = HeaderValidator.new
validator.main(ARGV)
