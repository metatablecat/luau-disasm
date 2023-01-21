-- Disassembler
-- metatablecat
-- Disassembles Luau bytecode into a usable spec
local Types = require(script.Parent.Types)
local Bytecode = require(script.Parent.Bytecode)
local Tostring = require(script.Parent.FormattedOutput)
local Opcodes = Bytecode.Opcodes
local ConstantTypes = Bytecode.Constants

local function Buffer(str): Types.Buffer
	local buffer = {}
	buffer.Offset = 0
	buffer.Source = str
	buffer.Length = string.len(str)
	buffer.IsFinished = false	

	function buffer.read(self: Types.Buffer, len: number?, shift: boolean?): string
		local len = len or 1
		local shift = if shift ~= nil then shift else true
		local dat = string.sub(self.Source, self.Offset + 1, self.Offset + len)

		if shift then
			self:seek(len)
		end

		return dat
	end

	function buffer.seek(self: Types.Buffer, len: number)
		local len = len or 1

		self.Offset = math.clamp(self.Offset + len, 0, self.Length)
		self.IsFinished = self.Offset >= self.Length
	end

	return buffer
end

local function disectImport(import: number, constants: {Types.Constant}): {Types.Constant}
	local count = bit32.rshift(import, 30)

	local k0 = constants[bit32.extract(import, 20, 10) + 1]
	local k1 = if count > 1 then constants[bit32.extract(import, 10, 10) + 1] else nil
	local k2 = if count > 2 then constants[bit32.band(import, 1023) + 1] else nil

	return {k0, k1, k2}
end

-- Start disassembly here
return function(bytecode: string): Types.Disassembly
	local buffer = Buffer(bytecode)

	local function readLEB128()
		local result = 0
		local b = 0 -- amount of bits to shift
		local c;

		repeat
			c = string.byte(buffer:read())
			local c2 = bit32.band(c, 0x7F)
			result = bit32.bor(result, bit32.lshift(c2, b))
			b += 7
		until not bit32.btest(c, 0x80)

		return result
	end

	local function readString()
		local len = readLEB128()
		return buffer:read(len)
	end

	local disassembly = {}
	-- start disecting bytecode
	disassembly.Version = string.byte(buffer:read()) --readLEB128()

	-- Strings
	local stringCount = readLEB128()
	local strings = table.create(stringCount)

	for stringIndex = 1, stringCount do
		strings[stringIndex] = readString()
	end

	disassembly.Strings = strings

	-- Prototypes
	local protoCount = readLEB128()
	local protos = table.create(protoCount)

	local nextInstIsAux = false
	local opcode: Types.Instruction
	local auxAlloc: number
	local opcodeID: number
	local param = 0
	
	for protoIndex = 1, protoCount do
		local proto = {}
		proto.Index = protoIndex - 1
		proto.StackSize = string.byte(buffer:read())
		proto.Params = string.byte(buffer:read())
		proto.Upvalues = string.byte(buffer:read())
		proto.IsVararg = buffer:read() == "\x01"

		-- Code
		local sizecode = readLEB128()
		local code = table.create(sizecode)

		for codeIndex = 1, sizecode do
			local unpacked, aux
				
			if nextInstIsAux then
				aux = string.unpack("<I4", buffer:read(4))
				unpacked = opcode:Decode(opcodeID, param, aux)
			else
				local storedCode = string.unpack("<I4", buffer:read(4))
				
				opcodeID = bit32.band(storedCode, 255)
				param = bit32.rshift(storedCode, 0x08)
				opcode = Opcodes[opcodeID]
				
				local isAux = opcode.AUX
				if isAux then
					nextInstIsAux = true
					auxAlloc = codeIndex
					continue
				end
				
				unpacked = opcode:Decode(opcodeID, param)
			end
			
			if nextInstIsAux then
				code[auxAlloc] = unpacked
				code[codeIndex] = {
					Name = "AUX",
					Value = aux
				}
				
				nextInstIsAux = false
			else
				code[codeIndex] = unpacked
			end
		end

		proto.Code = code

		-- Imports
		local sizek = readLEB128()
		local constants = table.create(sizek)

		for constantIndex = 1, sizek do
			local constant = {}
			constant.Type = "nil"
			constant.Value = nil

			local constantType = string.byte(buffer:read())

			if constantType == 1 then
				-- boolean
				constant.Type = "boolean"
				constant.Value = buffer:read() == "\x01"
			elseif constantType == 2 then
				-- number (double)
				constant.Type = "number"
				constant.Value = string.unpack("<d", buffer:read(8))
			elseif constantType == 3 then
				-- string
				constant.Type = "string"
				constant.Value = strings[readLEB128()]
			elseif constantType == 4 then
				-- import
				constant.Type = "import"
				constant.Value = disectImport(string.unpack("<I4", buffer:read(4)), constants)
			elseif constantType == 5 then
				-- table
				constant.Type = "table"

				local shape = table.create(readLEB128())
				for keyIndex = 1, shape do
					shape[keyIndex] = strings[readLEB128()]
				end

				constant.Value = shape
			elseif constantType == 6 then
				constant.Type = "closure"
				constant.Value = protos[readLEB128() + 1]
			end

			constants[constantIndex] = constant
		end

		proto.Constants = constants

		-- Inner Protos
		local innerProtoCount = readLEB128()
		local innerProtos = table.create(innerProtoCount)

		for innerProtoIndex = 1, innerProtoCount do
			innerProtos[innerProtoIndex] = proto[readLEB128() + 1]
		end

		proto.InnerProtos = innerProtos

		-- Debugs
		proto.LineDefined = readLEB128()

		local debugNameID = readLEB128()
		if debugNameID ~= 0 then
			proto.DebugName = strings[debugNameID]
		end

		if readLEB128() ~= 0 then
			-- Lineinfo
			local lineinfo = {}

			local linegaplog2 = string.byte(buffer:read())
			local intervals = bit32.rshift(sizecode - 1, linegaplog2) + 1

			local offsets = table.create(sizecode)
			for offsetIndex = 1, sizecode do
				offsets[offsetIndex] = string.byte(buffer:read())
			end

			local intervalTree = table.create(intervals)
			for intervalIndex = 1, intervals do
				intervalTree[intervalIndex] = {
					string.byte(buffer:read()),
					string.byte(buffer:read()),
					string.byte(buffer:read()),
					string.byte(buffer:read())
				}
			end

			lineinfo.offsets = offsets
			lineinfo.intervals = intervalTree
			proto.LineInfo = lineinfo
		end

		if readLEB128() ~= 0 then
			-- Debuginfo
			local debuginfo = {}

			local sizelocvars = readLEB128()
			local locvars = table.create(sizelocvars)

			for locvarIndex = 1, sizelocvars do
				locvars[locvarIndex] = {
					name = strings[readLEB128()],
					start = readLEB128(),
					finish = readLEB128(),
					register = string.byte(buffer:read())
				}
			end

			local sizeupvals = readLEB128()
			local upvals = table.create(sizeupvals)

			for upvalIndex = 1, sizeupvals do
				upvals[upvalIndex] = strings[readLEB128()]
			end

			debuginfo.locvars = locvars
			debuginfo.upvals = upvals
			proto.DebugInfo = debuginfo
		end

		protos[protoIndex] = proto
	end

	disassembly.Protos = protos
	local mainProtoID = readLEB128()
	disassembly.MainProto = protos[mainProtoID + 1]

	disassembly.Output = Tostring
	return disassembly
end