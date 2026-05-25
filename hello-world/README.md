# hello-world

A "hello world" QEMU example that boots a guest VM to print a friendly message.


## Overview

This is a "hello world"-style demo of QEMU. I've struggled to find and understand simple options to bootstrap a VM to do the thing I want it to do, and I keep coming back to [cloud-init][cloud-init]. It feels overkill for a "hello world", especially because I'm not running this in a cloud, but it works great. cloud-init is featureful software in its own, but let's keep the focus on concepts as they relate to QEMU. Consider these components of this demo:

- A VM base image
  - We download one of [Ubuntu's VM images][ubuntu-cloud-images] and use it as a base. This image is a file in QEMU's [qcow][qcow] file format.
- A "hello world" program
  - This program is embedded as a shell heredoc in the `user-data` YAML file. This is obnoxious. I can't figure out a sane way to just express a "hello.sh" script in a file, and wire it into the VM without much fuss. We are resorting to this cloud-init, YAML-bootstrapping dance. There has to be more fundamental ways...
- An overlay image
  - In this image, we've overlaid the base one to wire in the cloud init yaml??

The `build.sh` script creates a fresh qcow2 overlay for each run and uses macOS's built-in `hdiutil` tool to create the seed ISO. The seed ISO is where the "hello world" behavior is wired in. It contains:

- `user-data`
  - The cloud-init instructions. It writes `/usr/local/bin/hello-world`, runs it, mirrors its output to `/dev/ttyS0`,
    and powers off the guest.
- `meta-data`
  - The cloud-init instance identity. This demo uses a static `instance-id` because the overlay is recreated before each
    run. (TODO I don't get this. Do I need this?)

The generated artifacts are written to `artifacts/`:

- `noble-server-cloudimg-amd64.qcow2`
  - The cached Ubuntu cloud image downloaded from Ubuntu.
- `hello.qcow2`
  - The per-run writable overlay that QEMU boots.
- `seed.iso`
  - The NoCloud seed ISO with the `cidata` volume label.
- `serial.log`
  - The guest serial console output streamed by `run.sh`.


## Instructions

Follow these instructions to build and run the demo.

1. Pre-requisite: macOS, QEMU
   - I installed QEMU with Homebrew with the following command.
   - ```shell
     brew install qemu
     ```
2. Build the VM artifacts
   - ```shell
     ./build.sh
     ```
   - The first run downloads the Ubuntu cloud image. Later runs reuse the cached base image but recreate the writable
     overlay and seed ISO.
3. Run the VM
   - ```shell
     ./run.sh
     ```
   - It should eventually output the following message from the guest serial console.
   - ```text
     Hello from qemu-playground inside Ubuntu
     ```
   - The guest shuts itself down after cloud-init finishes.


## Wiring options

This demo uses cloud-init `write_files` plus `runcmd` because it keeps the Hello World program visible in the guest as a
normal executable while avoiding a custom image build.

Other reasonable options:

- Put a one-liner directly in `bootcmd` or `runcmd`
  - This is the smallest option, but there is no standalone program to inspect inside the guest.
- Attach another ISO or virtio disk with the program on it
  - This is useful when the payload should be kept separate from cloud-init. Cloud-init can mount the disk and run the
    program.
- Bake the program into a derived qcow2 image
  - This can make boot-time setup faster, but it makes the example less direct because now there is an image build step
    in addition to the QEMU run step.


## Wish List

General clean-ups, TODOs and things I wish to implement for this project:

* [ ] IN PROGRESS First iteration
* [ ] I should be able to mount a shell script. There heredoc can't be necessary


## Reference

- [Ubuntu cloud images](https://cloud-images.ubuntu.com/)
- [cloud-init: NoCloud](https://cloudinit.readthedocs.io/en/latest/reference/datasources/nocloud.html)
- [QEMU invocation documentation](https://www.qemu.org/docs/master/system/invocation.html)

[cloud-init]: https://cloud-init.io/
[ubuntu-cloud-images]: https://cloud-images.ubuntu.com
[qcow]: https://en.wikipedia.org/wiki/Qcow
