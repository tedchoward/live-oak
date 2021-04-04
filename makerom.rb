#!/usr/bin/env ruby

# frozen_string_literal: true

code = [
  0xA9, 0xFF,       # LDA #$FF
  0x80, 0x02, 0x60, # STA $6002

  0xA9, 0x55,       # LDA #$55
  0x80, 0x00, 0x60, # STA $6000

  0xA9, 0xAA,       # LDA #$AA
  0x80, 0x00, 0x60, # STA $6000

  0x4C, 0x05, 0x80  # JMP $8005
]

rom = code + Array.new(32_768 - code.length, 0xEA)

rom[0x7FFC] = 0x00 # CPU will "see" this as 0xFFFC
rom[0x7FFD] = 0x80

File.open('rom.bin', 'wb') do |f|
  rom.each { |byte| f.write(byte.chr) }
end
