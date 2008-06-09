#!/usr/bin/env ruby

$encoding_data_dir = "../data/encodings"
$encodings = ["ec", "qx", "texnansi", "t2a", "lmc", "il3"]

$output_data_dir = "../tex/conv_utf8"

class UnicodeCharacter
	def initialize(code_uni, code_enc, name)
		@code_uni = code_uni
		@code_enc = code_enc
		# TODO: might be longer or shorter
		@bytes    = [code_uni].pack('U').unpack('H2H2')
		@name     = name
	end
	
	attr_reader :code_uni, :code_enc, :bytes, :name
end

class UnicodeCharacters < Hash
	def add_new_character(code_uni, code_enc, name)
		first_byte = [code_uni].pack('U').unpack('H2').first
		if self[first_byte] == nil then
			self[first_byte] = Array.new
		end
		self[first_byte].push(UnicodeCharacter.new(code_uni, code_enc, name))
	end
end

# 0x19; U+0131;  1; dotlessi
$encodings.each do |encoding|
	#$utf_combinations = Hash.new
	$unicode_characters = UnicodeCharacters.new

	# those that need lccode to be set
	$lowercase_characters = Array.new

	File.open($encoding_data_dir + "/" + encoding + ".dat").grep(/^0x(\w+)\tU\+(\w+)\t(\d*)\t([_a-zA-Z\.]*)$/) do |line|
		# puts line
		code_enc = $1.hex
		code_uni = $2.hex
		if $3.length > 0
			type = $3.to_i
		else
			type = 0
		end
		name = $4
		if type == 1 then
			$unicode_characters.add_new_character(code_uni, code_enc, name)
			$lowercase_characters.push(UnicodeCharacter.new(code_uni, code_enc, name))
		end
	end
	
	$file_out = File.open("#{$output_data_dir}#{File::Separator}conv_utf8_#{encoding}.tex", "w")
	$file_out.puts "%% Conversion from UTF-8 to #{encoding.upcase} for 8-bit TeX engines"
	$file_out.puts

	$unicode_characters.sort.each do |first_byte|
		# sorting all the second characters alphabetically
		first_byte[1].sort!{|x,y| x.code_uni <=> y.code_uni }
		# make all the possible first characters active
		# output the definition into file
		$file_out.puts "\\catcode\"#{first_byte[0].upcase}=\\active"
	end
	$file_out.puts
	$unicode_characters.sort.each do |first_byte|
		$file_out.puts "\\def^^#{first_byte[0]}#1{%"
		string_fi = ""
		for i in 1..(first_byte[1].size)
			uni_character = first_byte[1][i-1]
			
			second_byte = uni_character.bytes[1]
			enc_byte    = uni_character.code_enc
			enc_byte    = [ uni_character.code_enc ].pack('c').unpack('H2')
			$file_out.puts "\t\\ifx#1^^#{second_byte}^^#{enc_byte}\\else % #{[uni_character.code_uni].pack('U')} - #{uni_character.name}"
			string_fi = string_fi + "\\fi"
		end
		$file_out.puts "\t\\errmessage{Hyphenation pattern file corrupted!}"
		$file_out.puts string_fi+"}"
	end
	$file_out.puts
	$file_out.puts "% ensure all the chars above have valid \lccode values"
	$lowercase_characters.sort!{|x,y| x.code_enc <=> y.code_enc }.each do |character|
		code = [ character.code_enc ].pack("c").unpack("H2").first.upcase
		# \lccode"FF="FF
		$file_out.puts "\\lccode\"#{code}=\"#{code} % #{[character.code_uni].pack('U')} - #{character.name}"
	end
	$file_out.puts
	
	if encoding == 'ec'
		$file_out.puts '% TODO: test if needed and the exact syntax'
		$file_out.puts '% some patterns use apostrophe and hyphen'
		# \lccode`\'=`\'
		$file_out.puts "\\lccode`\\'=`\\'"
		$file_out.puts "\\catcode`-=11"
		$file_out.puts
	end

	$file_out.close
end

