type Opcode = "AUX"
| "NOP"
| "BREAK"
| "LOADNIL"
| "LOADB"
| "LOADN"
| "LOADK"
| "MOVE"
| "GETGLOBAL"
| "SETGLOBAL"
| "GETUPVAL"
| "SETUPVAL"
| "CLOSEUPVALS"
| "GETIMPORT"
| "GETTABLE"
| "SETTABLE"
| "GETTABLEKS"
| "SETTABLEKS"
| "GETTABLEN"
| "SETTABLEN"
| "NEWCLOSURE"
| "NAMECALL"
| "CALL"
| "RETURN"
| "JUMP"
| "JUMPBACK"
| "JUMPIF"
| "JUMPIFNOT"
| "JUMPIFEQ"
| "JUMPIFLE"
| "JUMPIFLT"
| "JUMPIFNOTEQ"
| "JUMPIFNOTLE"
| "JUMPIFNOTLT"
| "ADD"
| "SUB"
| "MUL"
| "DIV"
| "MOD"
| "POW"
| "ADDK"
| "SUBK"
| "MULK"
| "DIVK"
| "MODK"
| "POWK"
| "AND"
| "OR"
| "ANDK"
| "ORK"
| "CONCAT"
| "NOT"
| "MINUS"
| "LENGTH"
| "NEWTABLE"
| "DUPTABLE"
| "SETLIST"
| "FORNPREP"
| "FORNLOOP"
| "FORGLOOP"
| "FORGPREP_INEXT"
| "V2_FORGLOOP_INEXT"
| "FORGPREP_NEXT"
| "V2_FORGLOOP_NEXT"
| "GETVARARGS"
| "DUPCLOSURE"
| "PREPVARARGS"
| "LOADKX"
| "JUMPX"
| "FASTCALL"
| "COVERAGE"
| "CAPTURE"
| "V2_JUMPIFEQK"
| "V2_JUMPIFNOTEQK"
| "FASTCALL1"
| "FASTCALL2"
| "FASTCALL2K"
| "FORGPREP"
| "JUMPXEQKNIL"
| "JUMPXEQKB"
| "JUMPXEQKN"
| "JUMPXEQKS"
	

export type UnpackedInstruction = {
	Opcode: number,
	Name: Opcode,
	AUX: number?,
	A: number?,
	B: number?,
	C: number?,
	D: number?,
	E: number?
}

export type Instruction = {
	Name: Opcode,
	ParamBitFlag: number, --Decoded manually
	AUX: boolean,
	Decode: (Instruction, opcode: number, param: number, aux: number?) -> UnpackedInstruction
}

export type Constant = {
	Type: "nil"|"boolean"|"double"|"string"|"import"|"table"|"closure",
	Value: nil
	| boolean
	| number
	| string
	| {Constant} -- import
	| {string} -- table
	| Proto -- proto
}

export type Proto = {
	Index: number,	
	StackSize: number,
	Params: number,
	Upvalues: number,
	IsVararg: boolean,

	-- Instructions are not decoded right now, please stand by
	Code: {UnpackedInstruction
		| {
			Name: "AUX",
			Value: number
		}
	},
	Constants: {Constant},
	InnerProtos: {Proto},
	LineDefined: number,
	DebugName: string?,
	LineInfo: {
		offsets: {number},
		intervals: {{number}}
	}?,

	DebugInfo: {
		locvars: {
			name: string,
			start: number,
			finish: number,
			register: number
		},
		upvals: {string}
	}?
}

export type Disassembly = {
	Version: number,
	Strings: {string},
	Protos: {Proto},
	MainProto: Proto,
	Output: (Disassembly) -> string
}

export type Buffer = {
	Offset: number,
	Source: string,
	Length: number,
	IsFinished: boolean,

	read: (Buffer, len: number?, shiftOffset: boolean?) -> string,
	seek: (Buffer, len: number) -> ()
}

return nil
