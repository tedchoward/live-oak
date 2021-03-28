#!/usr/bin/env ruby

# frozen_string_literal: true

rom = Array.new(32_768, 0xEA)

rom[0x7FFC] = 0x00 # CPU will "see" this as 0xFFFC
rom[0x7FFD] = 0x80

File.open('rom.bin', 'wb') do |f|
  rom.each { |byte| f.write(byte.chr) }
end
