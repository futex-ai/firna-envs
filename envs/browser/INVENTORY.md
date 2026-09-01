# Browser environment inventory

`firna-browser-v11` extends the v10 resizable native-Chrome environment without
changing its Chrome, Bowser, gcsfuse, or public stream-port pins. V11 replaces
Chrome's moving channel URL with its exact versioned package source, installs a
machine-readable Bowser runtime contract, and exercises kiosk launch, history,
and live inventory before release promotion. The release workflow publishes a
unique staging alias and assigns the immutable final alias only after that exact
template identity passes its smoke test.

V10 introduced distinct control channels for the two VNC servers, explicit
framebuffer rebuilds, and exact-geometry waits before resize acknowledgment.

## Display stack

- `Xtigervnc` supplies display `:0` and its runtime RandR framebuffer. Its RFB
  TCP listener is disabled; a mode-0600 Unix socket only keeps the headless X
  server active.
- Fluxbox keeps kiosk Chrome fullscreen as the root display changes.
- Two x11vnc servers continue to expose distinct loopback-only watch and
  control targets. Both monitor RandR changes; only the watch target carries
  `-viewonly`.
- Websockify retains ports 6080 and 6081 for Firna's authenticated outer
  router. No new Firna-owned network listener is part of v11.

## Screen helper

`/usr/local/bin/firna-screen` serializes `ensure` and `resize` with `flock`.
Its version-1 capability envelope advertises exact sizes between 320×240 and
3840×2160, up to 8,294,400 pixels. Resize validates before starting the stack,
creates one exact RandR mode, waits for X to report the requested geometry,
removes the preceding generated mode, and returns a machine-readable
acknowledgment.

The release smoke requires exact display, `screen`, and page-viewport geometry.
Chrome's `outerWidth` and `outerHeight` may retain a browser-owned minimum at
small display sizes, so they are required to contain the viewport but are not
the viewport-size contract.

The helper records the display, VNC, and WebSocket bridge PIDs beneath its
mode-0700 runtime directory. Verification reads those exact files and checks
the corresponding `/proc` command lines, avoiding false matches from shell or
agent command text.
