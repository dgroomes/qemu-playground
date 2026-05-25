# qemu-playground

📚 Learning and exploring QEMU.

> QEMU
> 
> A generic and open source machine emulator and virtualizer
> 
> -- <cite>https://www.qemu.org</cite>


## Overview

**NOTE**: This project was developed on macOS. It is designed for my own personal use.

I'm interested in using and learning more about QEMU so that I can better make use of virtual machines for my own workflows on macOS and on remote Linux machines.

More broadly, I'm interested in learning how to use the components up and down a _virtualization stack_ for my workflows. QEMU fits into this stack at a higher level abstraction than the hypervisors themselves. The [QEMU documentation site][qemu-docs] gets straight to the point. It describes that QEMU is a system _emulator_ and _virtualizer_. QEMU "provides a virtual model of an entire machine". It can [emulate a CPU in software with its Tiny Code Generator (TCG)][qemu-emulation], or it can delegate to a hypervisor which can run the virtual system (or just the CPU?) directly on the CPU. Start with the QEMU docs for learning it, and go to Wikipedia to quickly see how components of a virtualization stack tie-in together, like [hypervisors][wiki-hypervisor].

A note of caution: the literature does not agree about the exact definitions of things like Hypervisors and VMM (Virtual Machine Monitors). To me this is confusing, because I'm trying to build a mental model of these layers all the way from the low level (tech provided by Intel, AMD and Apple chips) to the higher level "management" layers like [libvirt][libvirt] and the [virsh][virsh] CLI frontend.


What I'd like to do with `qemu-playgrounds` is have some demos of building VM images, running them with various configurations of networking and disk, and controlling the VM lifecycle. I'd like to capture a working understanding of the fundamentals of QEMU in isolation of tools higher and lower on the virtualization stack.


## Standalone subprojects

This repository illustrates different concepts, patterns and examples via standalone subprojects. Each subproject is
completely independent of the others and do not depend on the root project. This _standalone subproject constraint_
forces the subprojects to be complete and maximizes the reader's chances of successfully running, understanding, and
re-using the code.

The subprojects include:


### `hello-world/`

A "hello world" QEMU example that boots a guest VM to print a friendly message.

See the README in [hello-world/](hello-world/).


## Wish List

General clean-ups, TODOs and things I wish to implement for this project:

* [x] DONE Scaffold the README
* [ ] IN PROGRESS Create a "hello world" demo. Bash script to run an Ubuntu VM with qemu and print hello world. I think we need to use cloud init, and I think we need to mount (?) an ISO into it which represents the actual hello world program?
* [ ] Image baking subproject. I want to learn how to customize an actual VM image. I need this to contrast with "mounting".


## Reference

* [QEMU][qemu-site]
* [QEMU docs][qemu-docs]


[qemu-site]: https://www.qemu.org
[qemu-docs]: https://www.qemu.org/docs/master/about/index.html
[wiki-hypervisor]: https://en.wikipedia.org/wiki/Hypervisor
[libvirt]: https://libvirt.org
[virsh]: https://www.libvirt.org/manpages/virsh.html
[qemu-emulation]: https://www.qemu.org/docs/master/about/emulation.html
