# planWorkflow Tests

This folder contains fast MATLAB unit tests for the `planWorkflow` package. The tests
cover configuration validation, analysis dose scaling, robustness strategies,
and workflow artifact persistence with synthetic data.

Run from MATLAB after the planWorkflow repository root is available on the path:

```matlab
planWorkflow.runTests();
```

When planWorkflow is used as a standalone toolbox, pass the matRad root explicitly:

```matlab
addpath('/path/to/external/planWorkflow');
planWorkflow.runTests('/path/to/matRad');
```
