# Browser environment inventory

`firna-browser-v6` evolves the v5 native-Chrome environment without changing
its Chrome, Bowser, gcsfuse, or public stream-port pins.

## Display stack

- `Xtigervnc` supplies display `:0` and its runtime RandR framebuffer. Its RFB
  TCP listener is disabled; a mode-0600 Unix socket only keeps the headless X
  server active.
- Fluxbox keeps kiosk Chrome fullscreen as the root display changes.
- Two x11vnc servers continue to expose distinct loopback-only watch and
  control targets. Both monitor RandR changes; only the watch target carries
  `-viewonly`.
- Websockify retains ports 6080 and 6081 for Firna's authenticated outer
  router. No new network listener is part of v6.

## Screen helper

`/usr/local/bin/firna-screen` serializes `ensure` and `resize` with `flock`.
Its version-1 capability envelope advertises exact sizes between 320×240 and
3840×2160, up to 8,294,400 pixels. Resize validates before starting the stack,
creates one exact RandR mode, waits for X to report the requested geometry,
removes the preceding generated mode, and returns a machine-readable
acknowledgment.
