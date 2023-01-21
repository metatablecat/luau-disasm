# Luau Bytecode Format

`version 3` - For the most part, previous versions will be correct, markers will be added for version specific sectors

Luau Bytecode is the underline format that Luau uses to run the code inside it's VM. Its a pretty basic format.

> Bytecode can be outputted using the `luau` cli tool with the following command:
> Run this command under `cmd`, not PowerShell
>
> ```batch
> luau --compile=binary in.lua >> a.out
> ```
>
> This command will output vanilla bytecode, not the bytecode format that Roblox uses internally.

## Conventions
The following conventions are used in this format
* All numbers are little-endian unless stated otherwise
* Fixed-precision numbers use Rust formatting
	* `u8` - Unsigned 8 bit number
	* `i16` - Signed 16 bit number
* `varint` refers to LEB128 for non-fixed length numbers

## Basic Structure
All Luau Bytecode files will have the basic structure
* `u8` - Version (3 known versions, currently `3`)
* `varint` - String Count
* `sizeof StringCount` Strings
* `varint` - Proto Count
* `sizeof ProtoCount` Protos
* `varint` Main Proto

## String Table
Luau uses a string table in every format for literally defined strings and names. If name debugs are enabled, function and var names will appear here as well. This table starts from 1 as 0 means `NULL` string

Strings are length-prefixed with a `varint`

## Prototypes
Prototypes are the main object for representing code inside the bytecode. All Prototypes have the structure:

```rs
struct Proto {
	stack_size: u8,
	params: u8,
	upvals: u8,
	is_vararg: u8,

	sizecode: varint,
	code: Vec!<u32> ,

	sizek: varint,
	imports: Vec!<Import> ,

	sizep: varint,
	constants: Vec!<varint>,

	linedefined: varint, // version 2 onwards
	debug_name_id: varint,

	has_line_info: u8,
	lineinfo: LineInfo, //only exists if has_line_info is 1

	has_debuginfo: u8,
	debuginfo: DebugInfo //only exists if has_debuginfo is 1
}
```

### Stack Size
Stack size declares how many registers should be allocated onto the stack, starts from R0

### Params
Number of params pushed onto the stack, starts from R0, so for example, if this is 2, values will be pushed into R0 and R1

### Upvals
Number of upvalues in the prototype, unlike params, these are not pushed onto the stack.

### Is Vararg
Declares if the function is variadic (has `...`), when this is 1, assume variadics exist. The main function will always be variadic

### Sizecode
A `varint` used to tell how many operations this prototype will perform.

### Code
Container holding unsigned 32-bit numbers representing an instruction. All prototypes should end with a `RETURN` instruction

Instructions follow the format:
|Instruction Opcode|`instruction_params`|
|-|-|
|`u8`|`u24`|

### `instruction_params`
Instruction parameters are declared in the bytecode specification, some bytecode operations may contain `AUX` instructions which mean the next instruction feeds into this instruction.

There are 7 known instruction rules:
|Rule|Shape|
|-|-|
|A|`u8` `00` `00`|
|AB|`u8` `u8` `00`|
|AB|`u8` `00` `u8`|
|ABC|`u8` `u8` `u8`|
|AD|`u8` `u16`|
|D| `00` `u16`|
|E|`u24`|


Or in another sense, lets take operation `GETIMPORT` which has the shape of `AD` followed by an `AUX`, 

In hex, this may be delcared as `[0C] [00] [01 00] [00 00 00 40]`

In this example:
* `0C` refers to the `GETIMPORT` instruction.
* `00` represents the register to push the value onto, since we use `AD` rule, this will be a `u8`
* `01 00` indicates the index in the Proto's import table, this is a `u16`.
* `00 00 00 40` is an auxilary instruction defined in the next instruction denoting the `import` object. See `Disecting Imports` for more information.

> Operations are declared under `Common/include/Luau/Bytecode.h` in the Luau source code

### Constants
`followed by sizek varint`

Following a `varint` declaring the size, holds constants used in the protoype, constants are declared below.

### Inner Protos
`followed by sizep varint`

Following a `varint` declaring the size, holds `varint` references to prototypes declared inside this prototype.

> For example:
> ```lua
> function a()
>   function b()
>
>   end
> end
> ```
>
> The `varint` pointing to the `b` proto, will appear in the `inner_proto` table of `a`

### Linedefined

This only exists if `version >= 2`. This is used to fix a bug with `debug.info` not calculating the defined line of a function correctly.

### Debug Name ID

References a string in the string table. If this is 0, assume no name is defined for this prototype.

### Lineinfo
Lineinfo is used to declare line offsets for the prototype, this is emitted on debug levels 1 and 2.

If the flag for this section is 0, assume this is not here.

### Debuginfo
Debuginfo is used to declare names for variables and upvalues, this only emits on debug level 2.

If the flag for this section 0, assume this is not here.

## Constants
Constants are used for prototypes to hold data. Constants have the basic structure of a `u8` typebit, followed by the data for that type.

There are 7 known constant types

|Bit|Name|Description|
|-|-|-|
|`0`|`nil`|`nil` import, Do nothing|
|`1`|`boolean`|Read next byte, `0` = false, `1` = true|
|`2`|`double`|Read a double (8 bytes long)|
|`3`|`string`|Read a varint and reference string table with it|
|`4`|`import`|See `Disecting Imports` below, read a `u32`|
|`5`|`table`|Initialiser for tables, see `Table Imports` below|
|`6`|`closure`|Protos loaded as closures, points to a proto ID|

### Disecting imports
Imports can hold up to 3 values in their u32 value. They can be disected using the following Lua code, where id is u32 value:

```lua
local count = bit32.rshift(id, 30)
local k0 = bit32.extract(id, 20, 10) + 1
local k1 = count > 1 and bit32.extract(id, 10, 10) + 1
local k2 = count > 2 and bit32.band(id, 1023) + 1
```

The k values will then point to indexes in the constant table, such that it forms `k0.k1.k2`. Remember, k1 and k2 could be nil.

> `import` constants should always be strings, if this is not the case, the file may be corrupted.

### Table Constants
From what I've seen, these are used to initialise tables with string keys.

This means a table declared like:
```lua
local t = {
	cat = "meow"
}
```

The constant will start with a `varint` declaring the length, so for example, the above here would be `1`, and then for each varint being read, it points to an index in the string table, which denotes a key in the table.

## Proto Debugs

### Line Info
TODO

> just leaving this here for reference so you dont have to dig through 20 different C files to find it
>
> `pc`, progam counter, refers to the current instruction being line checked
>
> If no line info, return `0`
>
> ```
> line = abslineinfo[pc >> linegaplog2] + lineinfo[pc]
> ```
>
> These are under `VM/src/ldebug.cpp` if you want other methods for working with the `lineinfo`

### Debug Info
Debug info is used to tell the VM the name values of registers and upvalues allocated into the prototype, this only appears when debug mode is set to `2`

Debug Info contains two child objects: `locvars` and `upvals`, both of which are used to allocate names to registers.
### `locvars`

Local Vars have the following struct:

|Name|Type|Description
|-|-|-|
|`name`|`varint`|Index from global string table|
|`start_op`|`varint`|Operation number where register is assigned this name|
|`end_op`|`varint`|Last operation where register has this name|
|`register`|`u8`|Register to assign name onto|

### `upvals`

Upvals is a table of references to the string table, when `CAPTURE` is used for this proto, the name of the upvalue is assigned to the relevant name in this table.
