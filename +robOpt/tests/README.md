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
addpath('/Users/acsevillam/workspace/matRad/robOpt');
robOpt.runTests('/Users/acsevillam/workspace/matRad/integration_varRBErobOpt_robOpt');
```
