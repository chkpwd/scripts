#!/usr/bin/env python3

"""Move files to another repo database"""

import shutil
from pathlib import Path

if __name__ == "__main__":
    src_file = Path.home().joinpath(
        "code", "scripts", "python", "ente-totp", "main.py"
    )
    dest_file = Path.home().joinpath(
        "code", "alfred-workflows", "ente-totp", "main.py"
    )

    shutil.copy(src_file, dest_file)
