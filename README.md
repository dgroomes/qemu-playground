# qemu-playground

📚Learning and exploring QEMU.

> QEMU
> 
> A generic and open source machine emulator and virtualizer
> 
> -- <cite>https://www.qemu.org</cite>


## Overview

I'm interested in using and learning more about QEMU so that I can better make use of virtual machines for my own workflows on macOS and on remote Linux machines.

The [QEMU documentation site][qemu-docs] gets straight to the point. It describes that QEMU is used for system emulation; either with full software emulation or by delegating to a hypervisor which can run the virtual system directly on the CPU. Start with the QEMU docs for learning.

What I'd like to do is have some demos of building VM images, running them with various configurations of networking and disk, and controlling the VM lifecycle. I'd like to capture a working understanding of the fundamentals in isolation from tooling that builds on top of QEMU (e.g libvirt).


## Wish List

General clean-ups, TODOs and things I wish to implement for this project:

- [x] DONE Scaffold the README
- [ ] Create a "hello world" demo. Bash script to run an Ubuntu VM with qemu and print hello world. I think we need to use cloud init, and I think we need to mount (?) an ISO into it which represents the actual hell world program?  


## Reference

- [QEMU][qemu-site]
- [QEMU docs][qemu-docs]


[qemu-site]: https://www.qemu.org
[qemu-docs]: https://www.qemu.org/docs/master/about/index.html
