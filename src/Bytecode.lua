-- Instruction Set
-- Feel free to rotate these as you need
-- Used to help decode in the parser
local Types = require(script.Parent.Types)

-- Known Instruction Param permutations
-- Definer
local InstructionBitFlag = {"A", "B", "C", "D", "E"}
local BitFlagAlignInst = {
	A = {shift = 0, mask = 0xFF},
	B = {shift = 8, mask = 0xFF},
	C = {shift = 16, mask = 0xFF},
	D = {shift = 8, mask = 0xFF_FF},
	E = {shift = 0, mask = 0xFF_FF_FF}
}
local AllowedBitFlagPermutations = {
	[0] = true, --None
	[1] = true, --A
	[3] = true, --AB
	[5] = true, --AC
	[7] = true, --ABC
	[8] = true, --D
	[9] = true, --AD
	[16] = true, --E
}
local function Instruction(name: string, paramRule: string?)
	local bitFlag = 0
	local aux = false
	
	if paramRule then
		aux = string.find(paramRule, "X") ~= nil
		
		for offset, flag in InstructionBitFlag do
			if string.find(paramRule, flag) then
				bitFlag += 2 ^ (offset - 1)
			end
		end
		
		if not AllowedBitFlagPermutations[bitFlag] then
			error("Bad instruction rule")
		end
	end
	
	return {
		Name = name,
		ParamBitFlag = bitFlag,
		AUX = aux,
		
		Decode = function(self, opcode: number, param: number, aux: number?)
			local inst = {}
			for offset, flag in InstructionBitFlag do
				local isRule = bit32.btest(self.ParamBitFlag, 2 ^ (offset - 1))
				
				if isRule then
					local useMode = BitFlagAlignInst[flag]
					local shift = useMode.shift
					local mask = useMode.mask
					
					-- (param >> shift) & mask
					inst[flag] = bit32.band(bit32.rshift(param, shift), mask)
				end
			end
			
			inst.Opcode = opcode
			inst.Name = self.Name
			inst.AUX = aux
			
			return inst
		end,
	}
	
end

-- Definition section
local Bytecode = {}
Bytecode.Opcodes = {
	-- Compiler hooks
	[0] = Instruction("NOP"), -- 0x00
	Instruction("BREAK"), -- 0x01
	
	-- Loaders
	Instruction("LOADNIL", "A"), -- 0x02
	Instruction("LOADB", "ABC"), -- 0x03
	Instruction("LOADN", "AD"), -- 0x04
	Instruction("LOADK", "AD"), -- 0x05
	
	Instruction("MOVE", "AB"), -- 0x06
	
	-- Getters/Setters
	Instruction("GETGLOBAL", "ACX"), -- 0x07
	Instruction("SETGLOBAL", "ACX"), -- 0x08
	Instruction("GETUPVAL", "AB"), -- 0x09
	Instruction("SETUPVAL", "AB"), -- 0x0A
	Instruction("CLOSEUPVALS", "A"),  -- 0x0B
	Instruction("GETIMPORT", "ADX"), -- 0x0C
	Instruction("GETTABLE", "ABC"), -- 0x0D
	Instruction("SETTABLE", "ABC"), -- 0x0E
	Instruction("GETTABLEKS", "ABCX"), -- 0x0F
	Instruction("SETTABLEKS", "ABCX"), -- 0x10
	Instruction("GETTABLEN", "ABC"), -- 0x11
	Instruction("SETTABLEN", "ABC"), -- 0x12
	
	-- Captures
	Instruction("NEWCLOSURE", "AD"), -- 0x13
	Instruction("NAMECALL", "ABCX"), -- 0x14
	Instruction("CALL", "ABC"), -- 0x15
	Instruction("RETURN", "AB"), -- 0x16
	
	-- Jumps
	Instruction("JUMP", "D"), -- 0x17
	Instruction("JUMPBACK", "D"), -- 0x18
	Instruction("JUMPIF", "AD"), -- 0x19
	Instruction("JUMPIFNOT", "AD"), -- 0x1A
	
	Instruction("JUMPIFEQ", "ADX"), -- 0x1B
	Instruction("JUMPIFLE", "ADX"), -- 0x1C
	Instruction("JUMPIFLT", "ADX"), -- 0x1D
	Instruction("JUMPIFNOTEQ", "ADX"), -- 0x1E
	Instruction("JUMPIFNOTLE", "ADX"), -- 0x1F
	Instruction("JUMPIFNOTLT", "ADX"), -- 0x20
	
	-- Operators A
	Instruction("ADD", "ABC"), -- 0x21
	Instruction("SUB", "ABC"), -- 0x22
	Instruction("MUL", "ABC"), -- 0x23
	Instruction("DIV", "ABC"), -- 0x24
	Instruction("MOD", "ABC"), -- 0x25
	Instruction("POW", "ABC"), -- 0x26
	
	Instruction("ADDK", "ABC"), -- 0x27
	Instruction("SUBK", "ABC"), -- 0x28
	Instruction("MULK", "ABC"), -- 0x29
	Instruction("DIVK", "ABC"), -- 0x2A
	Instruction("MODK", "ABC"), -- 0x2B
	Instruction("POWK", "ABC"), -- 0x2C
	
	Instruction("AND", "ABC"), -- 0x2D
	Instruction("OR", "ABC"), -- 0x2E
	Instruction("ANDK", "ABC"), -- 0x2F
	Instruction("ORK", "ABC"), -- 0x30
	Instruction("CONCAT", "ABC"), -- 0x31
	
	Instruction("NOT", "AB"), -- 0x32
	Instruction("MINUS", "AB"), -- 0x33
	Instruction("LENGTH", "AB"), -- 0x34
	
	-- Tables
	Instruction("NEWTABLE", "ABX"), -- 0x35
	Instruction("DUPTABLE", "AD"), -- 0x36
	Instruction("SETLIST", "ABCX"), -- 0x37
	
	-- For loops
	Instruction("FORNPREP", "AD"), -- 0x38
	Instruction("FORNLOOP", "AD"), -- 0x39
	Instruction("FORGLOOP", "ADX"), -- 0x3A
	Instruction("FORGPREP_INEXT", "A"), -- 0x3B
	Instruction("V2_FORGLOOP_INEXT", "A"), -- 0x3C
	Instruction("FORGPREP_NEXT", "A"), -- 0x3D
	Instruction("V2_FORGLOOP_NEXT", "A"), -- 0x3E
	
	-- Varargs
	Instruction("GETVARARGS", "AB"), -- 0x39
	Instruction("DUPCLOSURE", "AB"), -- 0x40
	Instruction("PREPVARARGS", "A"), -- 0x41
	
	-- X Jumping
	Instruction("LOADKX", "AX"), -- 0x42
	Instruction("JUMPX", "E"), -- 0x43
	
	Instruction("FASTCALL", "AC"), -- 0x44
	Instruction("COVERAEG", "E"), -- 0x45
	Instruction("CAPTURE", "AB"), -- 0x46
	
	Instruction("V2_JUMPIFEQK", "ADX"), -- 0x47
	Instruction("V2_JUMPIFNOTEQK", "ADX"),-- 0x48
	
	Instruction("FASTCALL1", "ABC"), -- 0x49
	Instruction("FASTCALL2", "ABCX"), -- 0x4A
	Instruction("FASTCALL2K", "ABCX"), -- 0x4B
	
	-- V3
	Instruction("FORGPREP", "AD"), -- 0x4C
	Instruction("JUMPXEQKNIL", "ADX"), -- 0x4D
	Instruction("JUMPXEQKB", "ADX"), -- 0x4E
	Instruction("JUMPXEQKN", "ADX"), -- 0x4F
	Instruction("JUMPXEQKS", "ADX"), -- 0x50
	
} :: {Types.Instruction}

Bytecode.Constants = {
	[0] = "nil",
	"boolean",
	"number",
	"string",
	"import",
	"table",
	"closure"
}

Bytecode.Fastcalls = {
	[0] = "NONE",
	
	-- assert()
	"assert",
	
	-- math
	"math.abs",
	"math.acos",
	"math.asin",
	"math.atan2",
	"math.atan",
	"math.ceil",
	"math.cosh",
	"math.cos",
	"math.deg",
	"math.exp",
	"math.floor",
	"math.fmod",
	"math.frexp",
	"math.ldexp",
	"math.log10",
	"math.log",
	"math.max",
	"math.min",
	"math.modf",
	"math.pow",
	"math.rad",
	"math.sinh",
	"math.sin",
	"math.sqrt",
	"math.tanh",
	"math.tan",
	
	-- bit32
	"bit32.arshift",
	"bit32.band",
	"bit32.bnot",
	"bit32.bor",
	"bit32.bxor",
	"bit32.btest",
	"bit32.extract",
	"bit32.lrotate",
	"bit32.lshift",
	"bit32.replace",
	"bit32.rrotate",
	"bit32.rshift",
	
	-- type()
	"type",
	
	-- string
	"string.byte",
	"string.char",
	"string.len",
	
	-- typeof()
	"typeof",
	
	-- string part 2
	"string.sub",
	
	-- math part 2
	"math.clamp",
	"math.sign",
	"math.round",
	
	-- metamethod bypass methods
	"rawset",
	"rawget",
	"rawequal",
	
	-- table
	"table.insert",
	"table.unpack",
	
	-- vector
	"Vector3.new",
	
	-- bit32 part 2
	"bit32.countlz",
	"bit32.countrz",
	
	-- select
	"select",
	
	-- rawlen
	"rawlen",
	
	-- metatables
	"getmetatable",
	"setmetatable"
}

Bytecode.Capture = {
	[0] = "VAL",
	"REF",
	"UPVAL"
}

return Bytecode