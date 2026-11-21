# M3 synthetic reply fixtures

These fixtures exercise `ReplyCompletionDetector` end to end without touching
real chat apps, user content, or the network. Everything here is synthetic and
lives under `build/fixtures` after building.

## Build

```bash
scripts/build-m3-fixtures.sh
```

This compiles the probe and a read-only AX phase sampler, then creates four
ad-hoc-signed app bundles with distinct bundle identifiers:

| App | Bundle id | Window title |
| --- | --- | --- |
| `ArgusFixtureA.app` | `com.bayernjf.argus-fixture-a` | `Argus Fixture A` |
| `ArgusFixtureB.app` | `com.bayernjf.argus-fixture-b` | `Argus Fixture B` |
| `ArgusFixtureC.app` | `com.bayernjf.argus-fixture-c` | `Argus Fixture C` |
| `ArgusFixtureD.app` | `com.bayernjf.argus-fixture-d` | `Argus Fixture D` |

## Modes

| Mode | Behavior | Used for |
| --- | --- | --- |
| `normal` | Streams synthetic lines, then removes spinner and Stop button | Positive: Idle → Streaming → Settling → Completed |
| `stall` | Freezes text for 3 s while spinner and Stop stay visible | Negative: must stay Streaming |
| `stallAx` | Freezes text and spinner for 4 s, leaves only an enabled AX Stop button | Negative: AX-only proof, must stay Streaming |
| `static` | Shows a completed reply with no generating control | Negative: must stay Idle |
| `blink` | Completed reply with a blinking caret | Negative: visual noise must not look Streaming |

Launch options: `--mode`, `--title`, `--delay`, `--chunks`, `--log`.

## Positive run

```bash
APPS=build/fixtures/Apps
rm -f /tmp/m3-p-*.log
open -n "$APPS/ArgusFixtureA.app" --args --mode normal --delay 8 --chunks 24 --log /tmp/m3-p-A.log
open -n "$APPS/ArgusFixtureB.app" --args --mode normal --delay 8 --chunks 26 --log /tmp/m3-p-B.log
open -n "$APPS/ArgusFixtureC.app" --args --mode normal --delay 8 --chunks 20 --log /tmp/m3-p-C.log
```

Add the three windows as Argus targets, then sample the visible phases:

```bash
build/fixtures/PhaseSampler 40 | tee /tmp/m3-positive-phases.log
```

Expected: all three reach `Completed`; each fixture's `last_text_change` to the
first `Completed` phase is at most 3 s (the M3 draft exit bar).

## Negative run

Stop the positive fixture processes first. The sampler matches the A/B/C card
titles, so keep those titles.

```bash
APPS=build/fixtures/Apps
rm -f /tmp/m3-n-*.log
open -n "$APPS/ArgusFixtureA.app" --args --mode static --title "Argus Fixture A" --log /tmp/m3-n-A.log
open -n "$APPS/ArgusFixtureB.app" --args --mode stallAx --delay 8 --chunks 12 --title "Argus Fixture B" --log /tmp/m3-n-B.log
open -n "$APPS/ArgusFixtureC.app" --args --mode blink --title "Argus Fixture C" --log /tmp/m3-n-C.log
build/fixtures/PhaseSampler 40 | tee /tmp/m3-negative-phases.log
```

Expected: A and C never leave `Idle`; B stays `Streaming` for the whole
`stallAx` window (4 s) and never enters `Settling` or `Completed` before
`stall_end`.

## Notes

- The event log contains timestamps and labels only (`launch`, `stream_start`,
  `last_text_change`, `stall_begin`, `stall_end`, `finish`). It never contains
  message text.
- `stallAx` is the only scenario that isolates Accessibility: spinner is stopped
  and text is frozen, so a visual-only detector would see completion. Run it with
  Accessibility permission granted to Argus if you want the AX path exercised;
  without permission the correct observable behavior is `Unknown`/low confidence,
  not `Completed`.
- Clean up test processes with `pkill -f ArgusChatProbe`; do not kill other apps.
