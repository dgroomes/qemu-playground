# hello-world

A "hello world" QEMU example that boots a guest VM to print a friendly message.


## Overview

This is a "hello world"-style demo of QEMU. I've struggled to find and understand simple options to bootstrap a VM to do the thing I want it to do, and I keep coming back to [cloud-init][cloud-init]. It feels overkill for a "hello world", especially because I'm not running this in a cloud, but it works great. cloud-init is featureful software in its own, but let's keep the focus on concepts as they relate to QEMU. Consider these components of this demo:

- A VM base image
  - We download one of [Ubuntu's VM images][ubuntu-cloud-images] and use it as a base. This image is a file in QEMU's [qcow][qcow] file format.
- A "hello world" program
  - This program is a normal shell script in `guest-share/`. QEMU exposes that directory to the guest, and cloud-init
    mounts it and runs the script.
- An overlay image
  - In this image, we've overlaid the base one to wire in the cloud init yaml??

The `build.sh` script creates a fresh qcow2 overlay for each run and uses macOS's built-in `hdiutil` tool to create the seed ISO. The seed ISO is where the "hello world" behavior is wired in. It contains:

- `user-data`
  - The cloud-init instructions. It mounts the QEMU host share, runs `hello-world.sh`, mirrors its output to
    `/dev/console` and `guest-share/hello-output.txt`, and powers off the guest.
- `meta-data`
  - The cloud-init instance identity. This demo uses a static `instance-id` because the overlay is recreated before each
    run. (TODO I don't get this. Do I need this?)

The generated artifacts are written to `artifacts/`:

- `resolute-server-cloudimg-arm64.qcow2`
  - The cached Ubuntu cloud image downloaded from Ubuntu.
- `hello.qcow2`
  - The per-run writable overlay that QEMU boots.
- `seed.iso`
  - The NoCloud seed ISO with the `cidata` volume label.
- `edk2-aarch64-vars.fd`
  - The per-run writable EDK2 variable store used by the ARM64 UEFI firmware.
- `serial.log`
  - The guest serial console output written by QEMU.


## Instructions

Follow these instructions to build and run the demo in a tutorial style.

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
3. Open a second terminal for logs
   - In terminal 2, start tailing the serial log.
   - ```shell
     tail -f artifacts/serial.log
     ```
4. Run the VM in terminal 1
   - ```shell
     ./scripts/start-qemu.sh
     ```
   - QEMU runs in the foreground here. It exits on its own when the guest powers off.
5. Watch for the hello-world output in terminal 2
   - ```text
     qemu-playground says hello!
     ```
   - The guest shuts itself down after cloud-init finishes, then `start-qemu.sh` exits.
6. Verify host-shared output file
   - ```shell
     cat guest-share/hello-output.txt
     ```
7. Stop the log tail
   - Press `Ctrl+C` in terminal 2.

### If you need to stop QEMU manually

The simplest way is `Ctrl+C` in terminal 1 where QEMU is running. If you want to stop it from
another terminal, find its PID and kill it:

- Find the QEMU process:
  - ```shell
    pgrep -af qemu-system-aarch64
    ```
- Kill it by PID (substitute the number from above):
  - ```shell
    kill <pid>
    ```
- If it ignores that, force kill:
  - ```shell
    kill -9 <pid>
    ```

### Convenience wrapper

`./run.sh` is still available as a convenience wrapper (`build.sh` + `scripts/start-qemu.sh`), but the steps above are the
preferred tutorial flow.


## Wiring options

This demo uses QEMU's 9p filesystem sharing plus cloud-init `runcmd`. That keeps the Hello World program as a normal
host-side shell script while still letting the guest execute it.

Other reasonable options:

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
