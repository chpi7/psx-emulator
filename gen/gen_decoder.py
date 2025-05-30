from pathlib import Path

MNEMONICS = [
  "LB",
  "LBU",
  "LH",
  "LHU",
  "LW",
  "LWL",
  "LWR",
  "SB",
  "SH",
  "SW",
  "SWL",
  "SWR",
  "ADDI",
  "ADDIU",
  "SLTI",
  "SLTIU",
  "ANDI",
  "ORI",
  "XORI",
  "LUI",
  "ADD",
  "ADDU",
  "SUB",
  "SUBU",
  "SLT",
  "SLTU",
  "AND",
  "OR",
  "XOR",
  "NOR",
  "SLL",
  "SRL",
  "SRA",
  "SLLV",
  "SRLV",
  "SRAV",
  "MULT",
  "MULTU",
  "DIV",
  "DIVU",
  "MFHI",
  "MTHI",
  "MFLO",
  "MTLO",
  "J",
  "JAL",
  "JR",
  "JALR",
  "BEQ",
  "BNE",
  "BLEZ",
  "BGTZ",
  "BLTZ",
  "BGEZ",
  "BLTZAL",
  "BGEZAL",
  "SYSCALL",
  "BREAK",
  "LWCz",
  "SWCz",
  "MTCz",
  "MFCz",
  "CTCz",
  "CFCz",
  "COPz",
  "BCzT",
  "BCzF",
  "MTC0",
  "MFC0",
  "TLBR",
  "TLBWI",
  "TLBWR",
  "TLBP",
  "RFE",
  "ILLEGAL",
]

# Opcodes from https://problemkaputt.de/psx-spx.htm#cpuspecifications
OPCODES_PRI_CSV = """
  00h=SPECIAL 08h=ADDI  10h=COP0 18h=N/A   20h=LB   28h=SB   30h=LWC0 38h=SWC0
  01h=BcondZ  09h=ADDIU 11h=COP1 19h=N/A   21h=LH   29h=SH   31h=LWC1 39h=SWC1
  02h=J       0Ah=SLTI  12h=COP2 1Ah=N/A   22h=LWL  2Ah=SWL  32h=LWC2 3Ah=SWC2
  03h=JAL     0Bh=SLTIU 13h=COP3 1Bh=N/A   23h=LW   2Bh=SW   33h=LWC3 3Bh=SWC3
  04h=BEQ     0Ch=ANDI  14h=N/A  1Ch=N/A   24h=LBU  2Ch=N/A  34h=N/A  3Ch=N/A
  05h=BNE     0Dh=ORI   15h=N/A  1Dh=N/A   25h=LHU  2Dh=N/A  35h=N/A  3Dh=N/A
  06h=BLEZ    0Eh=XORI  16h=N/A  1Eh=N/A   26h=LWR  2Eh=SWR  36h=N/A  3Eh=N/A
  07h=BGTZ    0Fh=LUI   17h=N/A  1Fh=N/A   27h=N/A  2Fh=N/A  37h=N/A  3Fh=N/A
"""

OPCODES_SEC_CSV = """
  00h=SLL   08h=JR      10h=MFHI 18h=MULT  20h=ADD  28h=N/A  30h=N/A  38h=N/A
  01h=N/A   09h=JALR    11h=MTHI 19h=MULTU 21h=ADDU 29h=N/A  31h=N/A  39h=N/A
  02h=SRL   0Ah=N/A     12h=MFLO 1Ah=DIV   22h=SUB  2Ah=SLT  32h=N/A  3Ah=N/A
  03h=SRA   0Bh=N/A     13h=MTLO 1Bh=DIVU  23h=SUBU 2Bh=SLTU 33h=N/A  3Bh=N/A
  04h=SLLV  0Ch=SYSCALL 14h=N/A  1Ch=N/A   24h=AND  2Ch=N/A  34h=N/A  3Ch=N/A
  05h=N/A   0Dh=BREAK   15h=N/A  1Dh=N/A   25h=OR   2Dh=N/A  35h=N/A  3Dh=N/A
  06h=SRLV  0Eh=N/A     16h=N/A  1Eh=N/A   26h=XOR  2Eh=N/A  36h=N/A  3Eh=N/A
  07h=SRAV  0Fh=N/A     17h=N/A  1Fh=N/A   27h=NOR  2Fh=N/A  37h=N/A  3Fh=N/A
"""

def convert_opcodes(s: str) -> dict:
    result = {}
    for op, mnemonic in [x.strip().split("=") for x in s.split(" ") if "=" in x]:
        if mnemonic != "N/A":
            result[int(op[:2], 16)] = mnemonic

    return result

OPCODES_PRI = convert_opcodes(OPCODES_PRI_CSV)
OPCODES_SEC = convert_opcodes(OPCODES_SEC_CSV)

def expand_mnemonics(input: list) -> list:
    result = []
    for m in input:
        if "z" in m:
            result += [m.replace("z", f"{i}") for i in (0,1,2,3)]
        else:
            result.append(m)
    return list(set(result))

MNEMONICS_EXPANDED = expand_mnemonics(MNEMONICS)

def emit_enum(name: str, defs: dict | list, type: str = "u8") -> str:

    if isinstance(defs, dict):
        tmp = sorted([f'{mn} = {op}' for op, mn in defs.items()])
    else:
        tmp = sorted(defs)
    return f"pub const {name} = enum({type}) {{ {', '.join(tmp)}, }};"


def op_to_mnemonic(fname: str, opcodes: dict) -> str:
    tmp = f"pub fn {fname}(v: u6) op {{\n"
    tmp += "return switch(v) {\n"
    lines = []
    for v, name in opcodes.items():
        if name in MNEMONICS_EXPANDED:
            lines.append(f'0x{v:02x} => op.{name},')
        
    lines.sort()
    tmp += "\n".join(lines)
    tmp += f'else => op.ILLEGAL,\n'
    tmp += "};\n}\n"
    return tmp


output_file = Path(__file__).parent.parent / "src" / "opcodes.zig"
with open(output_file, "wt") as f:
    f.write("/// What is encoded in the uppermost bits in every instruction.\n")
    f.write(emit_enum("primary", OPCODES_PRI, "u6"))
    f.write("\n")
    f.write("\n")
    f.write("/// What is encoded in funct in R type instructions.\n")
    f.write(emit_enum("subop", OPCODES_SEC, "u6"))
    f.write("\n")
    f.write("\n")
    f.write("/// The mnemonics for all operations with coprocessor ids expanded. (This doesn't correspond to anything in the ISA encoding!). Coprocessor ones MUST be sequential, otherwise the decoder will break!!!\n")
    f.write(emit_enum("op", MNEMONICS_EXPANDED, "u32"))
    f.write("\n\n")
    f.write(op_to_mnemonic("resolve_op", OPCODES_PRI))
    f.write("\n")
    f.write(op_to_mnemonic("resolve_subop", OPCODES_SEC))
    f.write("\n")
            


