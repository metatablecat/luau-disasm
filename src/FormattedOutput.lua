-- tostring function for disassembly, this is a bit more complex
--[[
Format:
DebugName(...) OR PROTO_0 based on debug name existance
BYTES 4/8  OPCODE

NOP and BREAK output NOP() and BREAK() respectively
]]
local BLOCK_COMMENT_MIN_LEN = 30 --26 is used # (str) #
local Bytecode = require(script.Parent.Bytecode)
local Types = require(script.Parent.Types)

local function BLOCK_COMMENT(txt)
	local less4 = BLOCK_COMMENT_MIN_LEN - 4
	local txtLen = string.len(txt)
	local commentLength = math.max(txtLen, less4)
	local inverseSpace = if txtLen then less4 - txtLen else 0
	
	local out = ""
	
	out ..= string.rep("#", commentLength) .. "\n"
	if inverseSpace > 0 then
		out ..= string.format("# %s%s #\n", txt, string.rep(" ", inverseSpace - 4))
	else
		out ..= string.format("# %s #\n", txt)
	end
	out ..= string.rep("#", commentLength) .. "\n"
	
	return out
	-- write long comment
end

local function packU32AsHex(packedNum)
	packedNum = string.split(packedNum, "")
	
	local out = {}
	for i = 1, 4 do
		local c = string.byte(packedNum[i])
		local x = string.upper(string.format("%x", c))
		if c < 16 then
			x = "0" .. x
		end
		out[i] = x
	end
	
	return table.concat(out, " ")
end

local function writeInstructionBytes(inst: Types.UnpackedInstruction)
	-- First, pack the bytes
	local num = 0
	num = inst.Opcode
	
	if inst.A then
		num += bit32.lshift(inst.A, 8)
	end
	
	if inst.B then
		num += bit32.lshift(inst.B, 16)
	end
	
	if inst.C then
		num += bit32.lshift(inst.C, 24)
	end
	
	if inst.D then
		num += bit32.lshift(inst.D, 16)
	end
	
	if inst.E then
		num += bit32.lshift(inst.E, 8)
	end	
	
	-- now, pack the string and output as hex
	local byteBuffer = packU32AsHex(string.pack("<I4", num))
	if inst.AUX then
		byteBuffer ..= " " .. packU32AsHex(string.pack("<I4", inst.AUX))
	else
		byteBuffer ..= "            "
	end
	
	return byteBuffer
end


local function writeInstruction(inst: Types.UnpackedInstruction, proto: Types.Proto)
	-- 80 branch if else :whoosh:
	-- To begin with, lets attach the raw bytes
	local buffer = writeInstructionBytes(inst)
	local instLine = inst.Name
	return string.format("%s  %s", buffer, instLine)
end

local function writeConstants(constants: {Types.Constant}): string
	-- index type value
	local stream = {}
	for idx, const in constants do
		local attachedBuffer
		if const.Type == "import" then
			-- imports are strings
			local values = {}
			for _, cv: Types.Constant in const.Value do
				table.insert(values, cv.Value)
			end
			
			attachedBuffer = table.concat(values, ".")
		elseif const.Type == "closure" then
			-- output func name
			local proto: Types.Proto = const.Value
			attachedBuffer = "." .. (proto.DebugName or "PROTO_" .. tostring(proto.Index))
		elseif const.Type == "table" then
			attachedBuffer = {}
			-- output keys as str, str, str ...
			for _, k in const.Value do
				table.insert(attachedBuffer, k)
			end
			
			attachedBuffer = string.format("{%s}", table.concat(attachedBuffer, ", "))
		else
			attachedBuffer = tostring(const.Value)
		end
		
		-- byte padding
		local padding = string.rep(" ", 7 - string.len(const.Type))
		
		table.insert(stream, string.format("%s%s  %s", string.upper(const.Type), padding, attachedBuffer))
	end
	
	return table.concat(stream, "\n") .. "\n"
end

type outputFlags = {
	ProcessDisectedLineInfo: (true|false)?
}

return function(self: Types.Disassembly, flags: outputFlags?): string
	flags = flags or {}
	local ProcessDisectedLineInfo = flags.ProcessDisectedLineInfo
	
	local buffer = string.format("Luau Bytecode Version: %s\n\n", self.Version)
	-- Begin writing out prototypes
	for idx, proto in self.Protos do
		local lastline, lineinfo = 0, {}
		if ProcessDisectedLineInfo then
			lastline = -1
			lineinfo = proto:DisectLineInfo()
		end
		
		-- get function name
		local funcName = if self.MainProto == proto
		then ".<entry>(%s)\n"
		else "." .. (proto.DebugName or "PROTO_" .. tostring(idx-1)) .. "(%s)\n"
		
		-- decode paramters
		local paramRegisters = {}
		if proto.Params > 0 then
			for i = 1, proto.Params do
				table.insert(paramRegisters, "R" .. tostring(i-1))
			end
		end
		
		if proto.IsVararg then
			table.insert(paramRegisters, "...")
		end
		
		local instructions = {}
		buffer ..= string.format(funcName, table.concat(paramRegisters, ", "))
		
		if not proto.LineInfo and ProcessDisectedLineInfo then
			table.insert(instructions, "! Proto did not have disectable lineinfo")
		end
		
		-- begin disecting lines
		local aux_offset = 0
		
		for instCount, inst in proto.Code do
			local line = lineinfo[instCount]
			if line ~= lastline and ProcessDisectedLineInfo then
				if lastline ~= -1 then
					table.insert(instructions, "")
				end
				
				lastline = line
			end
			
			if inst.Name == "AUX" then continue end
			table.insert(instructions, writeInstruction(inst, proto))
		end
		
		buffer ..= table.concat(instructions, "\n") .. "\n\n"
		
		-- write constants?
		buffer ..= "Constants\n"
		buffer ..= writeConstants(proto.Constants) .. "\n"
	end
	
	return buffer
end