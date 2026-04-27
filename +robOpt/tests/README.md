# robOpt Tests

This folder contains fast MATLAB unit tests for the `robOpt` package. The tests
cover configuration validation, analysis dose scaling, robustness strategies,
and workflow artifact persistence with synthetic data.

Run from MATLAB after the robOpt repository root is available on the path:

```matlab
robOpt.runTests();
```

When robOpt is used as a standalone toolbox, pass the matRad root explicitly:

```matlab
addpath('/path/to/external/robOpt');
robOpt.runTests('/path/to/matRad');
```
