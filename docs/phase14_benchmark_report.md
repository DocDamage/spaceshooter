# Phase 14 Benchmark Report

Automated target envelope: at least 60 average FPS; no sampled frame above 16.8 ms; at most 2,000 projectiles, 150 enemies, and 200 effects; generation under 100 ms; checkpoint save under 100 ms; results save under 250 ms. `VerticalSliceMetrics` records the average, worst frame, peaks, memory delta, generation time, checkpoint-save time, and results-save time. The acceptance workload runs 600 simulated frames at 60 FPS with 900 projectiles, 80 enemies, and 120 effects and must satisfy the envelope.

Representative headless measurements are diagnostic rather than GPU certification. The exported Windows build remains the release gate for hardware frame timing.
