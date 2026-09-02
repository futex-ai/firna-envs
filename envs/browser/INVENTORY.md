# Browser environment inventory

`firna-browser-v15` extends the v14 resizable native-Chrome environment without
changing its Chrome, Bowser, gcsfuse, or public stream-port pins. V15 replaces
Chrome's moving channel URL with its exact versioned package source, installs a
machine-readable Bowser runtime contract, and exercises kiosk launch, history,
and live inventory before release promotion. The release workflow publishes a
unique staging alias and assigns the immutable final alias only after that exact
template identity passes its smoke test.

V14 evolved the v5 native-Chrome environment without changing its Chrome,
Bowser, gcsfuse, or public stream-port pins. The published v6–v13
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
  router. No new Firna-owned network listener is part of v15.

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

Each x11vnc bridge consumes its native RandR notification. The screen helper
checks the bridge's recorded PID and loopback listener while polling its
reported framebuffer; it does not issue the remote reset command that can
crash x11vnc during a resize.

The helper records the display, VNC, and WebSocket bridge PIDs beneath its
mode-0700 runtime directory. Verification reads those exact files and checks
the corresponding `/proc` command lines, avoiding false matches from shell or
agent command text.
