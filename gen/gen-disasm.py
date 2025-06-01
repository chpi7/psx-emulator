import yaml
from pathlib import Path

INSTRUCTIONS_FILE = Path(__file__).parent / "instructions.yaml"
OUT_FILE = Path(__file__).parent.parent / "src" / "disasm_op_writer.zig"

TEMPLATE = """
const decoder = @import("decoder.zig");
const std = @import("std");

const I = decoder.I;
const Op = decoder.opcodes.op;

{{DECODERS}}

fn write_unknown(_: I, op: Op, w: anytype) !void {
    try w.print("{s}  <unknown>", .{@tagName(op)});
}

pub fn write_instruction(i: I, op: Op, w: anytype) !void {
    _ = try switch (op) {
{{CASES_OP_TO_TYPE}}
        else => write_unknown(i, op, w),
    };
}
"""

def check_encodings_complete(encodings: dict, instructions: list):
    instr_with_encoding = list()
    for _, instrs in encodings.items():
        instr_with_encoding += instrs
    missing_instructions = set(instructions) - set(instr_with_encoding)
    print("The following instructions don't have an encoding:", missing_instructions)

def get_instr_format(sub: dict):
    return sub.get("t", "R")


def emit_instr_format(name: str, sub: dict):
    operands = name.replace("op_", "").split("_")
    fmts = []
    srcs = []
    for o in operands:
        os = sub.get(o, o)
        if os in ("sys", "brk"):
            continue
        if os in ("rs", "rt", "rd", "re"):
            fmts.append("$r{d}")
            srcs.append(f"i.{get_instr_format(sub)}.{os}")
        elif os in ("imm", "target"):
            fmts.append("{x}")
            srcs.append(f"i.{get_instr_format(sub)}.{os}")
        else:
            fmts.append(f"<{os}>")
    return ", ".join(fmts), srcs

def emit_decoders(formats):
    decoders = []
    for name, sub in formats.items():
        header = f"fn write_{name}(i: I, op: Op, w: anytype) !void {{"
        instr_fmt, instr_srcs = emit_instr_format(name, sub or {}) 
        instr_srcs = ["@tagName(op)"] + instr_srcs
        instr_src = ", ".join(instr_srcs)
        body = f"    try w.print(\"{{s}}  {instr_fmt}\", .{{ {instr_src} }});"

        function = header + "\n" + body + "\n}\n"
        decoders.append(function)

    return "\n".join(decoders)

def emit_cases(encodings: dict, formats: dict) -> str:
    result = []
    for enc_name, instructions in encodings.items():
        if enc_name not in formats:
            enc_name = "unknown"
        for instr in instructions:
            result.append(f"        .{instr} => write_{enc_name}(i, op, w),")
    return "\n".join(result)


def main():
    with open(INSTRUCTIONS_FILE, "rt") as f:
        y = yaml.safe_load(f)

    encodings = y["instruction_encoding"]
    instrs = y["instructions"]
    formats = y["operand_encoding"]
    check_encodings_complete(encodings, instrs)

    decoders = emit_decoders(formats)
    cases = emit_cases(encodings, formats)

    code = TEMPLATE.replace("{{DECODERS}}", decoders).replace("{{CASES_OP_TO_TYPE}}", cases)

    with open(OUT_FILE, "wt") as f:
        f.write(code)


if __name__ == "__main__":
    main()
