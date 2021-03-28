#!/usr/bin/env ruby

# frozen_string_literal: true

rom = Array.new(32_768, 0xEA)

# LDA #$42
rom[0] = 0xA9
rom[1] = 0x42

# STA $6000
rom[2] = 0x8D
rom[3] = 0x00
rom[4] = 0x60

rom[0x7FFC] = 0x00 # CPU will "see" this as 0xFFFC
rom[0x7FFD] = 0x80

File.open('rom.bin', 'wb') do |f|
  rom.each { |byte| f.write(byte.chr) }
end
