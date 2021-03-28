#!/usr/bin/env ruby

# frozen_string_literal: true

rom = Array.new(32_768, 0xea)

puts rom

File.open('rom.bin', 'wb') do |f|
  rom.each { |byte| f.write(byte.chr) }
end
