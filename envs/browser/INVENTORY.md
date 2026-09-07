# Browser environment inventory

`firna-browser-v15` packages Bowser 0.4.0 from the verified release revision
`1e663325dd41de0363f6b80e2c07476ee7b902d0`. Its Linux amd64 archive SHA-256 is
`35199bdc2c802df5a02fdd38c9e0675a1b58c7d65afe52292ca0f2101e96f531`.
The [Bowser release](https://github.com/futex-ai/bowser/releases/tag/v0.4.0)
adds transient page favicons acquired inside the current browser context.
Release verification requires its capability, a real declared icon normalized
to a bounded 32×32 PNG, and icon-free ordinary inventory. The v14 display and
viewport contract below remains the foundation of this environment.

## Earlier display releases

`firna-browser-v14` evolves the v5 native-Chrome environment without changing
its Chrome, Bowser, gcsfuse, or public stream-port pins. The published v6–v13
candidates were not adopted. Their release diagnostics successively exposed
ambiguous global process discovery, E2B platform-owned forwarding listeners,
x11vnc recording its pre-daemonization parent PID, asynchronous RandR
propagation, and a persistent-client smoke deadlock. V11 proved the complete
runtime and VNC resize path but incorrectly required Chrome's outer window
chrome to equal the content viewport. V12 asserts the actual contract: exact
screen and inner-viewport metrics, while allowing outer dimensions to remain
larger where Chrome enforces a minimum window size. Its complete representative
suite exceeded the release runner's former four-minute command limit before it
could finish. V13 retains that contract and gives verification up to fourteen
minutes inside a fifteen-minute sandbox lifetime. Its full release smoke then
exposed the control x11vnc process crashing when E2B denied MIT-SHM attachment
during the first RandR change. V14 disables shared-memory polling on both
bridges and verifies the exact PID-owned loopback listener, so an E2B platform
forwarder cannot mask a dead bridge during idempotent ensure.

## Display stack

- `Xtigervnc` supplies display `:0` and its runtime RandR framebuffer. Its RFB
  TCP listener is disabled; a mode-0600 Unix socket only keeps the headless X
  server active.
- Fluxbox keeps kiosk Chrome fullscreen as the root display changes.
- Two x11vnc servers continue to expose distinct loopback-only watch and
  control targets. Both monitor RandR changes; only the watch target carries
  `-viewonly`.
- Websockify retains ports 6080 and 6081 for Firna's authenticated outer
  router. No new Firna-owned network listener is part of v14.

## Screen helper

`/usr/local/bin/firna-screen` serializes `ensure` and `resize` with `flock`.
Its version-1 capability envelope advertises exact sizes between 320×240 and
3840×2160, up to 8,294,400 pixels. Resize validates before starting the stack,
creates one exact RandR mode, waits for X to report the requested geometry,
removes the preceding generated mode, and returns a machine-readable
acknowledgment.

The helper records the display, VNC, and WebSocket bridge PIDs beneath its
mode-0700 runtime directory. Verification reads those exact files and checks
the corresponding `/proc` command lines, avoiding false matches from shell or
agent command text.
