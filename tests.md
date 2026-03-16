# Performance & Efficiency Report: NepaliPatro

This document outlines the performance benchmarks, resource consumption, and algorithmic complexity for the NepaliPatro macOS Menu Bar application.

## 1. Summary of Benchmarks
*Executed on Apple Silicon (M-series) / Intel macOS.*

| Metric | Result | Impact |
| :--- | :--- | :--- |
| **Average Conversion Time** | 0.018 ms (18.07 microseconds) | Negligible |
| **Max Conversions/Sec** | ~55,000 operations | High Throughput |
| **Memory Footprint (App)** | ~25 MB - 45 MB | Very Low |
| **JSON Load Time** | < 5 ms | Instant Startup |

## 2. Algorithmic Complexity (Big O)
The core logic resides in `NepaliCalendar`.

*   **`convertToBSDate(from:)`**: $O(D)$  
    Where $D$ is the number of days since the anchor date (2003-04-14). For current dates (~23 years), this is ~8,400 iterations, executing in microseconds.
*   **`firstWeekday(year:month:)`**: $O(Y + M)$  
    Where $Y$ is years since anchor and $M$ is months. It is a linear scan that is computationally trivial for the modern CPU.
*   **`loadCalendarData()`**: $O(N)$  
    Standard JSON decoding of the 63KB data file.

## 3. Resource Consumption Details

### CPU Usage
*   **Idle State**: 0.0% CPU. The app is passive and does not run background loops.
*   **Interaction State**: < 5% CPU spike during UI animations (handled by SwiftUI). The calendar logic itself consumes < 0.1% of a single core's capacity.

### Memory Usage
*   **SwiftUI Runtime**: ~20-30 MB (Standard macOS framework overhead).
*   **Application Data**: < 1 MB. The 63KB `calendar.json` expands minimally when decoded into Swift Dictionaries.
*   **Binary Size**: Estimated ~300 KB - 500 KB (Stripped release build).

## 4. Methodology
To verify these results, an isolated performance script (`perf_test.swift`) was used to run 10,000 iterations of the core `convertToBSDate` logic.

### Reproduction Command:
```bash
swift perf_test.swift
```

### Script Logic:
The script measures:
1.  **Resident Set Size (RSS)** using `mach_task_basic_info`.
2.  **Execution Time** using `CFAbsoluteTimeGetCurrent()`.
3.  **Throughput** by looping 10,000 times through the conversion engine.

---
*Last Updated: March 16, 2026*
