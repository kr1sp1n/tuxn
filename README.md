# tuxn

Implementation of [uxn][1] in tcl/tk.

Download [tclkit][2] for your platform with the Tk package and make it executable.

Build rom:
```bash
uxnasm test/hello-pixel.tal test/hello-pixel.rom
```

Run rom:
```bash
tclkit src/emu.tcl test/hello-pixel.rom
```

---

[1]: https://git.sr.ht/~rabbits/uxn
[2]: https://kitcreator.rkeene.org/kitcreator