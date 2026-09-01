# Browser environment inventory

`firna-browser-v12` evolves the v5 native-Chrome environment without changing
its Chrome, Bowser, gcsfuse, or public stream-port pins. The published v6–v11
candidates were not adopted. Their release diagnostics successively exposed
ambiguous global process discovery, E2B platform-owned forwarding listeners,
x11vnc recording its pre-daemonization parent PID, asynchronous RandR
propagation, and a persistent-client smoke deadlock. V11 proved the complete
runtime and VNC resize path but incorrectly required Chrome's outer window
chrome to equal the content viewport. V12 asserts the actual contract: exact
screen and inner-viewport metrics, while allowing outer dimensions to remain
larger where Chrome enforces a minimum window size.

## Display stack

- `Xtigervnc` supplies display `:0` and its runtime RandR framebuffer. Its RFB
  TCP listener is disabled; a mode-0600 Unix socket only keeps the headless X
  server active.
- Fluxbox keeps kiosk Chrome fullscreen as the root display changes.
- Two x11vnc servers continue to expose distinct loopback-only watch and
  control targets. Both monitor RandR changes; only the watch target carries
  `-viewonly`.
- Websockify retains ports 6080 and 6081 for Firna's authenticated outer
  router. No new Firna-owned network listener is part of v12.

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
