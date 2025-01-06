# LlmSwift
A SwiftUI implementation of [llm.swift](https://github.com/otabuzzman/llm.swift.git). Built just for fun on iPad using Swift Playgrounds 4 to see if it works.

## Build and run
Copy folder `LlmSwift.swiftpm` to iPad and open it in Swift Playgrounds 4. Upload app to TestFlight and install it from there as a *real* app to run it at maximum performance. Running it in Playground's preview mode is possible in principle, but it is far too slow.

## Notes
The app may crash due to a CPU usage event that occurs on iOS devices to prevent the UI from hanging. The event occurs when CPU usage exceeds 50 percent for 180 seconds, as noted in the crash report snippet below.

```
Event:            cpu usage
Action taken:     none
CPU:              90 seconds cpu time over 98 seconds (92% cpu average), exceeding limit of 50% cpu over 180 seconds
CPU limit:        90s
Limit duration:   180s
CPU used:         90s
CPU duration:     98s
Duration:         98.00s
Duration Sampled: 92.72s (event starts 3.68s before samples, event ends 1.60s after samples)
Steps:            135
```