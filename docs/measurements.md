# Bench Measurements

Numbers measured on one Jetson Orin Nano Super Dev Kit (p3767-0005 on p3768-0000), L4T R36.4.7 / JetPack 6.2.1, kernel 5.15.148-tegra, NVMe root, stock heatsink and fan, open air on the bench. November 2026.

The load used here is a synthetic worst case, not a flight workload. Treat the numbers as limits to plan around, and measure your own pipeline the same way.

## The 25 W limit

The Orin Nano 8GB Super has a 25 W limit on its 5 V input. NVIDIA's `/etc/systemd/nvpower.sh` writes it at every boot into the module's INA3221 power monitor, as 25 W divided by the input voltage it measures:

```bash
# limit in mA (about 5000 on a dev kit) and the live input voltage in mV
cat /sys/class/hwmon/hwmon*/curr1_crit /sys/class/hwmon/hwmon*/in1_input 2>/dev/null
```

When the module draws more than that, the kernel counts an over-current event and the CPU clock is cut. Heat has nothing to do with it. Watch the counters while your software runs:

```bash
grep -H . /sys/class/hwmon/hwmon*/oc*_event_cnt
```

If the numbers go up, the board is throttling. Under throttling, tegrastats shows the CPU well below the mode's maximum (862 MHz or 364 MHz in the runs below), and `dmesg` fills with lines like `cpufreq: cpu0,cur:863000,set:1728000`.

## All-out load, per power mode

Load: `stress --cpu 6 --vm 2 --vm-bytes 768M` plus a loop of fp16 4096 x 4096 matrix multiplies on the GPU. Fan at 100% unless noted. Readings every 10 s from tegrastats, the thermal zones and the over-current counters.

| Setup | Run | Input power | Slowest CPU core | GPU | GPU throughput | Over-current events | Peak temp |
|---|---|---|---|---|---|---|---|
| MAXN_SUPER + `jetson_clocks`, desktop install | 5 min | 27.3-27.8 W | 862 MHz (of 1728) | 1020 MHz | 7.6-7.7 TFLOPS | about 16 per second | 67 °C |
| MAXN_SUPER, headless install | 4.7 min | 28.8-29.4 W | 862 MHz | 1020 MHz | 7.4-7.7 TFLOPS | about 3 per second | 69.5 °C |
| 25W mode | 2.3 min | 24.6-24.9 W | 364 MHz (of 1344) | 918 MHz | 7.0 TFLOPS | about 60 per second | 61 °C, still rising |
| MAXN_SUPER, CPU capped at 1036 MHz, GPU pinned at 1020 MHz, fan on auto | 3.3 min | 26.7-27.4 W | 364 MHz | 1020 MHz | 7.4-7.6 TFLOPS | about 29 per second | 69 °C |
| MAXN_SUPER, CPU capped at 806 MHz | 50 s | 26.4-27.0 W | 364 MHz | 1020 MHz | 7.6 TFLOPS | about 30 per second | short run |

The same GPU loop running alone, with no CPU or memory stress, reached 7.8-7.9 TFLOPS.

What this shows:

- Power was the limit, not heat. Kernel throttling for heat starts at 99 °C on this board and the hottest reading was 69.5 °C.
- Every setup tested hit the limit under this load. The 15W mode was not tested.
- The GPU kept its clock and almost all of its throughput. The CPU paid for it: half speed in MAXN_SUPER, about a quarter in the other setups.
- Capping the CPU lower did not help. The GPU and memory draw most of the power, so the board still went over the limit and pushed the CPU down further.
- The 25W mode sat right at the limit, crossed it more often than any other setup, and the CPU ended up slower than in MAXN_SUPER.
- The event count is not a measure of how bad the throttling is. The headless MAXN_SUPER run drew the most power, had the CPU at half speed the whole time, and logged the fewest events.

A real vision pipeline uses far less CPU and memory than this test, so it may stay under 25 W in MAXN_SUPER. The counters above tell you.

## Idle power

| State | Input power |
|---|---|
| Desktop install, idle | 4.9 W |
| Headless install, no monitor attached at boot | 5.0 W |
| Headless install, monitor attached at boot | 7.3 W |
| Headless install, monitor attached, after `jetson_clocks` | 8.9 W |

- A monitor costs about 2.3 W on a headless install. If one is plugged in at boot, the firmware switches the display on for the text console and nothing ever switches it off, even if you unplug the cable later. Booted without a monitor, the same install idles at 5.0 W, and 1.8 W of the drop is on the SoC rail where the display block sits. (Unused services were also trimmed between those two readings, so the split is not exact.)
- `jetson_clocks` costs about 1.6 W at idle. It pins all six cores at 1728 MHz, disables the CPU idle states, keeps the GPU powered at 1020 MHz and locks the memory clock at 3199 MHz.

## Temperatures

- Idle with the fan forced to 100%: 47 °C fell to 39 °C in one minute and settled near 34 °C.
- Kernel trip points: CPU and GPU throttling at 99 °C, shutdown at 104 °C. The 70 °C trip only raises a hot-surface warning.

## Wake-up latency

Stock kernel (it is built with `CONFIG_PREEMPT`), one `SCHED_FIFO` thread at priority 80 waking every 1 ms with `clock_nanosleep`, idle system, 6000 samples per run.

| CPU idle state c7 | Average | Worst |
|---|---|---|
| Disabled | 2 µs | 12 µs on cpu5, 51 µs on cpu0 |
| Enabled (the default) | 166 µs | 204 µs |

So the deep idle state adds a steady 0.17 ms to every wake-up. To switch it off for the two cores of the small cluster:

```bash
echo 1 | sudo tee /sys/devices/system/cpu/cpu{4,5}/cpuidle/state1/disable
```

These runs were on an idle system. Latency under a real load was not measured.

## Trimming a headless install

Same board, same SSD, before and after switching off what a headless flight computer does not use.

| | Before | After |
|---|---|---|
| Startup (kernel + userspace) | 19.5 s (8.5 + 10.9) | 13.2 s (8.6 + 4.6) |
| Memory used at idle | about 410 MB | 297 MB |

For comparison, the full desktop install on the same board uses 2.3 GB at idle.

What was switched off (`sudo systemctl disable --now <name>`):

- `NetworkManager-wait-online.service`. This one alone was 7 s of the startup time.
- `bluetooth`, `ModemManager`, `docker`, `docker.socket`, `containerd`, `isc-dhcp-server`, `isc-dhcp-server6`
- `nvmemwarning`, `nvidia-pva-allowd` (this module has no PVA), `haveged`, `networkd-dispatcher`, `rtkit-daemon`, `lxcfs`, `seatd`, `rsyslog`, `syslog.socket`
- `jtop`. Start it when you want the dashboard: `sudo systemctl start jtop`
- Timers: `apt-daily`, `apt-daily-upgrade`, `man-db`, `motd-news`, `apport-autoreport`, `e2scrub_all`, `dpkg-db-backup`
- The audio server: `sudo systemctl --global mask pipewire.service pipewire.socket pipewire-media-session.service`

Also changed: the default target is `multi-user.target` (`sudo systemctl set-default multi-user.target`), and the boot service that runs `jetson_clocks` was left disabled for these readings.

Still running afterwards: NetworkManager, wpa_supplicant, ssh, nvargus-daemon (cameras), nvfancontrol, nvpmodel, nv-tee-supplicant, nvphs, nvs-service and the systemd basics. After the changes the board started with no failed units.

Only disable what you do not use. If you need Bluetooth or Docker, leave them on.

## Limits of these numbers

One board, one power supply, short runs, a synthetic load. They are here so you know what to look for, not as a specification.
