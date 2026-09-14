# Quietform A Surface — implementation QA

Device and simulator rendering were intentionally not started because the saved project preference assigns device-side debugging to the user. The first pass was reviewed from the complete SwiftUI layout and state graph, followed by a targeted second pass.

## Functional contract

- Purpose: help a person start and automate a focus restriction using Apple Screen Time APIs.
- Three-second information: current focus state, what is selected, and the next available action.
- Required actions: choose apps, start/stop a timed or continuous session, create recurring time/place rules, recover from missing permission or scheduling errors.

## Reference DNA

- Apple: one interactive blue, 44 pt minimum targets, 48 pt primary control, semantic system canvas, restrained shadow, and glass only for elevated surfaces.
- OpenAppLock: complete rule behavior as a product benchmark, without copying its name, icon, screenshots, or store wording.

## First-pass critique

- Art direction: the page needed a single unmistakable focus state instead of opening on an app-management list.
- Engineering: schedules were foreground polling only and the schedule editor did not support weekdays.
- Product: rules could be created before selecting any apps without explaining why they would not visibly run.
- Readability: the next-schedule row repeated its start time twice.

## Second-pass corrections

- Added a dedicated status hero with one primary action and a compact real-data summary strip.
- Added DeviceActivity background monitoring, a monitor extension, weekday recurrence, overnight evaluation, and timed-session completion.
- Added an explicit selection prerequisite with a direct recovery action on the Rules page.
- Removed the duplicated time from the next-schedule summary and distinguished an active rule from a paused current interval.

## Craft details shipped

1. Native liquid-glass elevation is limited to actionable surfaces.
2. The protection/focus mark is displayed directly without an extra icon tile.
3. The status hero changes its semantic mark, copy, primary action, and tint as one coherent state.
4. Countdown digits use monospaced figures to prevent layout jitter.
5. Rule state combines a status dot, plain-language state, weekday summary, and exact time range.
6. Permission and scheduling failures include an immediate recovery action rather than a dead-end message.
