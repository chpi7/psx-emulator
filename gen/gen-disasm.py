import yaml
from pathlib import Path

INSTRUCTIONS_FILE = Path(__file__).parent / "instructions.yaml"

def check_encodings_complete(encodings: dict, instructions: list):
    instr_with_encoding = list()
    for _, instrs in encodings.items():
        instr_with_encoding += instrs
    missing_instructions = set(instructions) - set(instr_with_encoding)
    print("The following instructions don't have an encoding:", missing_instructions)


def main():
    with open(INSTRUCTIONS_FILE, "rt") as f:
        y = yaml.safe_load(f)

    encodings = y["instruction_encoding"]
    instrs = y["instructions"]
    # print(encodings, type(encodings))
    # print()
    # print(instrs, type(instrs))
    check_encodings_complete(encodings, instrs)


if __name__ == "__main__":
    main()
