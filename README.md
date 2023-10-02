# Bazel rules for ts_proto

## Installation

From the release you wish to use:
<https://github.com/gonzojive/rules_ts_proto/releases>
copy the WORKSPACE snippet into your `WORKSPACE` file.


## Generated import statements

The majority of the complexity in this library comes from how imports work in
the world of TypeScript and JavaScript.

### From the NodeJS documentation

NodeJS documentation of [ECMASCript modules](https://nodejs.org/api/esm.html)
has an [import specifiers
section](https://nodejs.org/api/esm.html#import-specifiers). It defines three
types of import specifiers. One of them is

> *Relative specifiers* like `'./startup.js'` or `'../config.mjs'`. They refer
> to a path relative to the location of the importing file. The file extension
> is always necessary for these.


`rules_ts_proto` generates relative import statements that use absolute
extensions for this reason.


### See also

* [TypeScript's module resolution
  page](https://www.typescriptlang.org/docs/handbook/module-resolution.html)
