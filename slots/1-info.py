# Path, type, size, date and permissions of the marked items - or of the one under the cursor
import os
import stat
import sys
import time

import gk

targets = gk.marked() or ([gk.cursor()] if gk.cursor() else [])
if not targets:
    print("nothing under the cursor")
    sys.exit(0)

for path in targets:
    try:
        st = os.lstat(path)
    except OSError as e:
        print("?          %s  (%s)" % (path, e.strerror))
        continue
    kind = "dir" if stat.S_ISDIR(st.st_mode) else "link" if stat.S_ISLNK(st.st_mode) else "file"
    owner = ""
    try:
        import grp
        import pwd

        owner = "%s:%s" % (pwd.getpwuid(st.st_uid).pw_name, grp.getgrgid(st.st_gid).gr_name)
    except (ImportError, KeyError):  # Windows: no owner here - its attributes instead
        attrs = getattr(st, "st_file_attributes", 0)
        flags = [("R", stat.FILE_ATTRIBUTE_READONLY), ("H", stat.FILE_ATTRIBUTE_HIDDEN),
                 ("S", stat.FILE_ATTRIBUTE_SYSTEM), ("A", stat.FILE_ATTRIBUTE_ARCHIVE)] if attrs else []
        owner = "".join(letter if attrs & bit else "-" for letter, bit in flags)
    when = time.strftime("%Y-%m-%d %H:%M", time.localtime(st.st_mtime))
    print("%s %-12s %10d %s %-4s %s" % (stat.filemode(st.st_mode), owner, st.st_size, when, kind, path))
