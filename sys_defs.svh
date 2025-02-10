
/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.svh                                        //
//                                                                     //
//  Description :  This file has the macro-defines for macros used in  //
//                 the pipeline design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __SYS_DEFS_SVH__
`define __SYS_DEFS_SVH__


// NOTE: moved this into sys_defs.svh, don't add to any other files
// have all files `include "sys_defs.svh" from now on (why weren't we doing this before?)
`timescale 1ns/100ps

// Synthesis testing definition for parameterized modules tested at multiple sizes
// see lab 6 CAM for example usage
`ifdef SYNTH_TEST
`define INSTANCE(mod) mod``_svsim
`else
`define INSTANCE(mod) mod
`endif

//////////////////////////////////////////////
//
// DEBUG
//
//////////////////////////////////////////////

`define DEBUG_OUT_RS 1
`define DEBUG_OUT_EX 1
`define DEBUG_OUT_MAP_TABLE 1
`define DEBUG_OUT_FREE_LIST 1
`define DEBUG_OUT_DISPATCH 1
`define DEBUG_OUT_ROB 1
`define DEBUG_OUT_FETCH 1
`define DEBUG_OUT_LSQ 1
`define DEBUG_OUT_DCACHE 1
`define DEBUG_OUT_ICACHE 1
`define DEBUG_OUT_COMPLETE 1


//////////////////////////////////////////////
//
// Memory/testbench attribute definitions
//
//////////////////////////////////////////////

// NOTE: the CLOCK_PERIOD definition has been moved to the Makefile

// cache mode removes the byte-level interface from memory, so it always returns a double word
// the original processor won't work with this defined
// so your new processor will have to account for our changes to mem

//TODO: Uncomment out this line
`define CACHE_MODE // MUST BE DEFINED FOR FINAL PROCESSOR

// you are not allowed to change this definition for your final processor
`define MEM_LATENCY_IN_CYCLES (100.0/`CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period). The default behavior for
// float to integer conversion is rounding to nearest

// the original p3 definition - can be useful for temporarily testing non-memory functionality
// `define MEM_LATENCY_IN_CYCLES 0


`define LEFT_YOUNGER_OR_EQUAL(head, in1, in2) ((in1 < head && head <= in2) || (head <= in2 && in2 < in1 ) || (in2 < in1 && in1 < head) || (in1 == in2))
`define LEFT_STRICTLY_YOUNGER(head, in1, in2) ((in1 < head && head <= in2) || (head <= in2 && in2 < in1 ) || (in2 < in1 && in1 < head))

`define NUM_MEM_TAGS 15

`define MEM_SIZE_IN_BYTES (64*1024)
`define MEM_64BIT_LINES   (`MEM_SIZE_IN_BYTES/8)

// RISCV ISA SPEC
`define XLEN 32

`define BTB_SIZE 50
`define LOG_BTB_SIZE $clog2(`BTB_SIZE + 1)


// useful boolean single-bit definitions
`define FALSE  1'h0
`define TRUE  1'h1

// RISCV ISA SPEC
`define XLEN 32

typedef union packed {
    logic [7:0][7:0]  byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
} EXAMPLE_CACHE_BLOCK;

typedef enum logic [1:0] {
	BYTE = 2'h0,
	HALF = 2'h1,
	WORD = 2'h2,
	DOUBLE = 2'h3
} MEM_SIZE;


//////////////////////////////////////////////
// Exception codes
// This mostly follows the RISC-V Privileged spec
// except a few add-ons for our infrastructure
// The majority of them won't be used, but it's
// good to know what they are
//////////////////////////////////////////////

typedef enum logic [3:0] {
	INST_ADDR_MISALIGN  = 4'h0,
	INST_ACCESS_FAULT   = 4'h1,
	ILLEGAL_INST        = 4'h2,
	BREAKPOINT          = 4'h3,
	LOAD_ADDR_MISALIGN  = 4'h4,
	LOAD_ACCESS_FAULT   = 4'h5,
	STORE_ADDR_MISALIGN = 4'h6,
	STORE_ACCESS_FAULT  = 4'h7,
	ECALL_U_MODE        = 4'h8,
	ECALL_S_MODE        = 4'h9,
	NO_ERROR            = 4'ha, //a reserved code that we modified for our purpose
	ECALL_M_MODE        = 4'hb,
	INST_PAGE_FAULT     = 4'hc,
	LOAD_PAGE_FAULT     = 4'hd,
	HALTED_ON_WFI       = 4'he, //another reserved code that we used
	STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;

//////////////////////////////////////////////
//
// Datapath control signals
//
//////////////////////////////////////////////

// ALU opA input mux selects
typedef enum logic [1:0] {
	OPA_IS_RS1  = 2'h0,
	OPA_IS_NPC  = 2'h1,
	OPA_IS_PC   = 2'h2,
	OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

// ALU opB input mux selects
typedef enum logic [3:0] {
	OPB_IS_RS2    = 4'h0,
	OPB_IS_I_IMM  = 4'h1,
	OPB_IS_S_IMM  = 4'h2,
	OPB_IS_B_IMM  = 4'h3,
	OPB_IS_U_IMM  = 4'h4,
	OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

// Destination register select
typedef enum logic [1:0] {
	DEST_RD = 2'h0,
	DEST_NONE  = 2'h1
} DEST_REG_SEL;

typedef enum logic [4:0] {
	ALU_ADD     = 5'h00,
	ALU_SUB     = 5'h01,
	ALU_SLT     = 5'h02,
	ALU_SLTU    = 5'h03,
	ALU_AND     = 5'h04,
	ALU_OR      = 5'h05,
	ALU_XOR     = 5'h06,
	ALU_SLL     = 5'h07,
	ALU_SRL     = 5'h08,
	ALU_SRA     = 5'h09,
	ALU_MUL     = 5'h0a,
	ALU_MULH    = 5'h0b,
	ALU_MULHSU  = 5'h0c,
	ALU_MULHU   = 5'h0d,
	ALU_DIV     = 5'h0e,
	ALU_DIVU    = 5'h0f,
	ALU_REM     = 5'h10,
	ALU_REMU    = 5'h11,
	ALU_INVALID	= 5'h1f //Invalid should be maximum value
} ALU_FUNC;

typedef enum logic [2:0] {
	BRANCH_BEQ = 3'b000,
	BRANCH_BNE = 3'b001,
	BRANCH_BLT = 3'b100,
	BRANCH_BGE = 3'b101,
	BRANCH_BLTU = 3'b110,
	BRANCH_BGEU = 3'b111
} BRANCH_FUNC;

//////////////////////////////////////////////
//
// SuperScalar Things
//
//////////////////////////////////////////////

`define N 5
`define logN $clog2(`N+1)

//////////////////////////////////////////////
//
// Functional Units
//
//////////////////////////////////////////////

// ALU function code input
// probably want to leave these alone
typedef enum logic [4:0] {
	ALU     = 5'h01,
	FP     	= 5'h02,
	LD      = 5'h03,
	
	INVALID = 5'h00
	//IMPORTANT: Change NUM_FUNC_UNIT_TYPES if we change this
} FUNC_UNITS;

`define NUM_FUNC_UNIT_TYPES  4
`define NUM_ROBS 		8 // IMPORTANT: MUST BE A POWER OF 2. We use overflow, which only works if it's a power of 2.
`define NUM_ROBS_BITS 	8 // log2(NUM_ROBS)

`define NUM_ROWS 8
`define NUM_REGISTERS 32
`define NUM_ARCH_BITS 	5  // log2(NUM_REGISTERS)
`define NUM_PHYS_REGS 	(`NUM_REGISTERS + `NUM_ROBS) // DO NOT CHANGE, otherwise we have extra structural hazards.
`define NUM_PHYS_BITS 	6  // log2(NUM_PHYS_REGS)
`define ROB_ENTRIES 32
`define NUM_REG_BITS 5
//`define NUM_PHYS_BITS $ceil($log2(32 + ROB_ENTRIES))

`define NUM_ALU `N
`define NUM_FP `N
`define NUM_LD `N
`define NUM_ST `N
`define NUM_INVALID `N

//////////////////////////////////////////////
//
// Map Table Structs 
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`NUM_PHYS_BITS - 1 : 0] phys_reg;
	logic ready;
} MAP_TABLE_ENTRY;
// note that map table entries are always valid because the map table is initially 
// set to r1->p1 ... r32->p32


///////////////////////////////////////////////
//
// Load store queue structures
//
//////////////////////////////////////////////
`define LQ_SIZE     8
`define LQ_N_SIZE   (`LQ_SIZE+`N)
`define LQ_BITS     $clog2(`LQ_SIZE)

`define SQ_SIZE     8
`define SQ_N_SIZE   (`SQ_SIZE+`N)
`define SQ_BITS     $clog2(`SQ_SIZE)

`define CMD_SIZE    (`LQ_SIZE +`SQ_SIZE)
`define CMD_BITS    $clog2(`CMD_SIZE)


typedef struct packed {
    logic                       retire;
    logic [`NUM_ROBS_BITS-1:0]  rob_id;
} RETIRE_ROW;

// Memory bus commands control signals.
//	Do not change
typedef enum logic [1:0] {
	BUS_NONE     = 2'h0,
	BUS_LOAD     = 2'h1,
	BUS_STORE    = 2'h2
} BUS_COMMAND;

/*
typedef struct packed {
    BUS_COMMAND                 mem_cmd;
    logic [`XLEN-1:0]           mem_addr;
    logic [63:0]                mem_data;
    logic [`NUM_PHYS_BITS-1:0]  tag_dest;
    logic                       valid;
    logic [`NUM_ROBS_BITS-1:0]  rob_id;
} LSQ_ROW;
*/

typedef struct packed {
	logic [`XLEN-1:0]			PC;
    logic [`XLEN-1:0]           mem_addr;
    logic [63:0]                mem_data;
    logic [`NUM_PHYS_BITS-1:0]  tag_dest;
    logic                       complete;
    logic                       error_detect;
    logic                       valid;
	logic						retire_bit;
    logic [`NUM_ROBS_BITS-1:0]  rob_id;
	logic [`LQ_BITS-1:0]		age; // location of LQ tail pointer at birth
	logic [`SQ_BITS-1:0]		store_tail;		
	MEM_SIZE					mem_size;			
} LQ_ROW;

typedef struct packed {
	logic [`XLEN-1:0]			PC;
	logic [`NUM_ROBS_BITS-1:0]  rob_id;
	MEM_SIZE mem_size;
	logic valid;
	logic is_store;
} DISPATCHED_LSQ_PACKET;

typedef struct packed {
	logic [`XLEN-1:0]			PC;
    logic [`XLEN-1:0]           mem_addr;
    logic [63:0]                mem_data;
    logic                       complete;
	logic						value;
    logic                       valid;
	logic						retire_bit;
    logic [`NUM_ROBS_BITS-1:0]  rob_id;
	logic [`LQ_BITS-1:0]		age; // location of LQ tail pointer at birth
	logic [`SQ_BITS-1:0]		load_tail;
	MEM_SIZE					mem_size;
} SQ_ROW;


typedef struct packed {
	logic [`NUM_ROBS_BITS-1:0]		head_rob_id;
	logic [`NUM_ROBS_BITS-1:0]		mispeculated_rob_id;
	logic [`XLEN-1:0]				mispeculated_PC;
	logic [`XLEN-1:0]				mispeculated_old_PC;
	logic 							is_branch_mispredict;
} FLUSHED_INFO;

/*typedef struct packed {
    BUS_COMMAND                 mem_cmd;
    logic [`NUM_ROBS_BITS-1:0]  rob_id;
} CMD_ROW;*/


///////////////////////////////////////////////
//
// Reservation Station Structs
//
//////////////////////////////////////////////


`define NUM_RES_STATIONS 16
`define NUM_RES_BITS 4
`define DEBUG_MODE 0


typedef struct packed{
	logic [31:0] opcode;
	logic [`NUM_REG_BITS-1:0] arch_reg_1;
	ALU_OPA_SELECT reg_1_select;
	logic [`NUM_REG_BITS-1:0] arch_reg_2;
	ALU_OPB_SELECT reg_2_select;
	logic [`NUM_REG_BITS-1:0] arch_dest;
	DEST_REG_SEL reg_dest_select;
} DECODED_INSTRUCTION;



//////////////////////////////////////////////
//
// ROB Structs 
//
//////////////////////////////////////////////
typedef struct packed {
	logic [`XLEN-1:0] PC;
	logic halt_detected;
	logic illegal_inst_detected;
	logic wr_reg;
	logic wr_mem;
	logic rd_mem;
	MEM_SIZE mem_size;
} WB_OUTPUTS;

typedef struct packed {
	logic [`NUM_REG_BITS - 1:0] arch_reg_dest;
    logic [`NUM_PHYS_BITS - 1:0] phys_reg_dest;
	logic [`NUM_PHYS_BITS - 1:0] old_phys_reg_dest;
    logic [`NUM_ROBS_BITS - 1:0] rob_id;
    logic complete;
	logic busy;
	logic branch_mispredict;
	logic [`XLEN-1:0] branch_target;
	WB_OUTPUTS wb_output;
} ROB_ROW;

typedef struct packed {
    logic [31:0] opcode;
    logic [`NUM_PHYS_BITS - 1:0] phys;
    logic [`NUM_ARCH_BITS - 1:0] arch;
    logic complete;
} PHYS_ARCH_PAIR;

//////////////////////////////////////////////
//
// CDB Structs 
//
//////////////////////////////////////////////

typedef struct packed {
	// N physical registers
	// N valid bits
	logic [`NUM_PHYS_BITS-1:0] phys_regs;
	logic valid;
	logic branch_mispredict;
	logic [`NUM_ROBS_BITS-1:0] rob_id;
	logic [`XLEN-1:0] result;
	logic [`XLEN-1:0] PC_plus_4;
	logic is_uncond_branch;
	logic halt;
	logic illegal;
} CDB_ROW;

///////////////////////////////////////////////
//
// Struct for free list
//
//////////////////////////////////////////////


//////////////////////////////////////////////
//
// Assorted things it is not wise to change
//
//////////////////////////////////////////////

// standard delay - use after all non-blocking assignments
`define SD #1

// the RISCV register file zero register, any read of this register always
// returns a zero value, and any write to this register is thrown away
`define ZERO_REG 5'd0





typedef union packed {
	logic [31:0] inst;
	struct packed {
		logic [6:0] funct7;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} r; //register to register instructions
	struct packed {
		logic [11:0] imm;
		logic [4:0]  rs1; //base
		logic [2:0]  funct3;
		logic [4:0]  rd;  //dest
		logic [6:0]  opcode;
	} i; //immediate or load instructions
	struct packed {
		logic [6:0] off; //offset[11:5] for calculating address
		logic [4:0] rs2; //source
		logic [4:0] rs1; //base
		logic [2:0] funct3;
		logic [4:0] set; //offset[4:0] for calculating address
		logic [6:0] opcode;
	} s; //store instructions
	struct packed {
		logic       of;  //offset[12]
		logic [5:0] s;   //offset[10:5]
		logic [4:0] rs2; //source 2
		logic [4:0] rs1; //source 1
		logic [2:0] funct3;
		logic [3:0] et;  //offset[4:1]
		logic       f;   //offset[11]
		logic [6:0] opcode;
	} b; //branch instructions
	struct packed {
		logic [19:0] imm;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} u; //upper immediate instructions
	struct packed {
		logic       of; //offset[20]
		logic [9:0] et; //offset[10:1]
		logic       s;  //offset[11]
		logic [7:0] f;	//offset[19:12]
		logic [4:0] rd; //dest
		logic [6:0] opcode;
	} j;  //jump instructions
`ifdef ATOMIC_EXT
	struct packed {
		logic [4:0] funct5;
		logic       aq;
		logic       rl;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} a; //atomic instructions
`endif
`ifdef SYSTEM_EXT
	struct packed {
		logic [11:0] csr;
		logic [4:0]  rs1;
		logic [2:0]  funct3;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} sys; //system call instructions
`endif

} INST; //instruction typedef, this should cover all types of instructions

//////////////////////////////////////////////
//
// Basic NOP instruction.  Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
//
//////////////////////////////////////////////

`define NOP 32'h00000013

//////////////////////////////////////////////
//
// Caching Packets:
// Data structures needed for cache 
// arbitration and memory requests
//
//////////////////////////////////////////////

typedef enum logic [1:0] {
	TAGNone,
	Dcache,
	Icache, 
	Pfetch
} TAG_LOCATION;

typedef enum logic [0:0] {
	load_op,
	store_op
} CACHE_OPERATION;

typedef struct packed {
	logic [`XLEN-1:0] 		addr;
	logic [63:0] 			data;
	MEM_SIZE				size;
	logic					valid;
} MEMORY_STORE_REQUEST;

typedef struct packed {
	logic [`XLEN-1:0]	addr;
	logic 				valid;
} INST_LOAD_REQUEST;


typedef struct packed {
	logic 					valid;
	logic [`XLEN-1:0] 		addr;
	logic [63:0] 			data;
	BUS_COMMAND 			command;
} MEMORY_REQUEST;



typedef struct packed {
	logic [3:0]       	response;
	logic [63:0] 		data;
	logic [3:0] 		tag;
} MEMORY_RESPONSE;

typedef enum logic [1:0] {
	Invalid	= 'h0,
	Valid	= 'h1, // dirty |-> valid
	Dirty	= 'h3,
	Evicted	= 'h2	// an evicted block has valid data, but a 
					// store request has already been sent to memory
					// cannot be written to, but can be read from 
} CACHE_STATUS;


typedef struct packed {
	logic [63:0] 	line;
	logic			valid;
	logic [`XLEN-1:0] addr;
	MEM_SIZE size;
} CACHE_ROW;

typedef struct packed {
	logic [`XLEN-1:0] 	inst;
	logic				valid;
	logic [`XLEN-1:0] 	addr;
} CACHE_INST;


`define CACHE_LINES 32
`define CACHE_LINE_BITS $clog2(`CACHE_LINES)

typedef struct packed {
	EXAMPLE_CACHE_BLOCK				block;
	// 12:0 (13 bits) since only 16 bits of address exist in mem - and 3 are the block offset
	logic [12-`CACHE_LINE_BITS:0]	tag;
	CACHE_STATUS					status;
} DCACHE_PACKET;


typedef struct packed {
	logic [63:0]                  data;
	// 12:0 (13 bits) since only 16 bits of address exist in mem - and 3 are the block offset
	logic [12-`CACHE_LINE_BITS:0] tag;
	logic                         valid;
} ICACHE_PACKET;

typedef struct packed {
	logic [12-`CACHE_LINE_BITS:0]	tag;
	logic [`CACHE_LINE_BITS-1:0] 	index;
	logic							valid;
	BUS_COMMAND						command;
	logic [3:0] 					mem_tag;
	logic [`XLEN-1:0] 				addr;
} ICACHE_REQ;


//////////////////////////////////////////////
//
// Branch Prediction Packets:
// Data structures needed for branch prediction
//
//////////////////////////////////////////////


typedef enum logic [1:0] {
	S_NOT_TAKEN     = 2'h0,
	W_NOT_TAKEN     = 2'h1,
	S_TAKEN			= 2'h2,
	W_TAKEN    		= 2'h3
} BRANCH_PREDICTOR_FSM;


typedef struct packed {
	logic [`XLEN-1:0] predict_target;
	logic valid;
	BRANCH_PREDICTOR_FSM predictor;
} BTB_ROW;


//////////////////////////////////////////////
//
// IF Packets:
// Data that is exchanged between the IF and the ID stages
//
//////////////////////////////////////////////

typedef struct packed {
	logic valid; // number of fetched instructions
    INST  inst;  // fetched instruction out
	logic [`XLEN-1:0] NPC; // PC + 4
	logic [`XLEN-1:0] PC;  // PC
} IF_ID_PACKET;

typedef struct packed {
	logic [`XLEN-1:0] addr; // last two bits should always be zero because 
	logic valid;
} IF_INST_REQ;

//////////////////////////////////////////////
//
// ID Packets:
// Data that is exchanged from ID to EX stage
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] NPC; // PC + 4
	logic [`XLEN-1:0] PC;  // PC

	logic [`XLEN-1:0] rs1_value; // reg A value
	logic [`XLEN-1:0] rs2_value; // reg B value
	
	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_reg_idx;  // destination (writeback) register index
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	MEM_SIZE	mem_size;	   // what is the memory size of inst if it reads or writes memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?
} ID_EX_PACKET;

// if we are doing static this should be  struct packed 
// if we are doing dynamic this should be union  packed
typedef struct packed {
	logic [`NUM_ROBS_BITS - 1:0] rob_id;
	logic [`NUM_PHYS_BITS - 1:0] tag_dest;
	logic [`NUM_PHYS_BITS - 1:0] tag_1;
	logic [`NUM_PHYS_BITS - 1:0] tag_2;			
	logic ready_tag_1;					
	logic ready_tag_2;					
	logic busy;	// i.e. valid
	FUNC_UNITS functional_unit;
	
	logic [`XLEN-1:0] PC; 
	logic [`XLEN-1:0] NPC; 	//If not a branch, or branch predicted not taken: PC + 4
							//If branch predicted taken: Branch Target
	INST inst;
	ALU_FUNC    alu_func;
	ALU_OPA_SELECT opa_select;
	ALU_OPB_SELECT opb_select;

	MEM_SIZE mem_size;
	logic cond_branch;
	logic uncond_branch;
	logic halt;
	logic illegal;
} RESERVATION_ROW;

typedef struct packed {
	logic valid;
	
	logic [`XLEN-1:0] PC;
	logic [`XLEN-1:0] NPC; 	//If not a branch, or branch predicted not taken: PC + 4
							//If branch predicted taken: Branch Target
							
	logic [`XLEN-1:0] rs1_value; 	//These need to be set by the PHYS reg file; 
	logic [`XLEN-1:0] rs2_value;	//	cannot come directly from RS

	INST inst;
	ALU_FUNC    alu_func;
	FUNC_UNITS functional_unit;
	ALU_OPA_SELECT opa_select;
	ALU_OPB_SELECT opb_select;

	logic cond_branch;
	logic uncond_branch;

	MEM_SIZE size;
	logic [`NUM_ROBS_BITS - 1:0] rob_id;		
  	logic [`NUM_PHYS_BITS - 1:0] dest_reg;	//Physical Destination Register
	logic halt;
	logic illegal;
} RS_EX_PACKET;





//////////////////////////////////////////////
//
// EX Packets:
// Data that is output from EX
//
//////////////////////////////////////////////
typedef struct packed {
	logic [`XLEN-1:0] address;
	logic [`NUM_ROBS_BITS-1:0] rob_id; 
	MEM_SIZE size;
	logic valid;
} EX_LD_REQ;

typedef struct packed {
	logic [`XLEN-1:0] 				result; //FU result
	logic [`XLEN-1:0] 				PC;
	logic 							branch_mispredict;
	logic [`NUM_ROBS_BITS - 1:0] 	rob_id; //pass-through from dispatch
	logic [`NUM_PHYS_BITS - 1:0] 	dest_reg; //pass-through from dispatch
	logic 							is_uncond_branch;
	logic 							is_ld;
	logic 							is_signed; //For Loads Only
	logic 							valid;
	logic 							halt;
	logic 							illegal;
} EX_CP_PACKET;

typedef struct packed {
	logic [`XLEN-1:0] address;
	logic [`XLEN-1:0] value;
	logic [`NUM_ROBS_BITS-1:0] rob_id; 
	logic is_signed;
	MEM_SIZE size;
	logic valid;
} EX_LSQ_PACKET;



`endif //Entire file endif
