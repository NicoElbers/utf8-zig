# UTF8-zig

A small and relatively fast UTF8 encoder and decoder library.

## Why

I'm not a fan of the current implementation in `std`; this implementation is
explicitly made to never crash.

This implementation replaces invalid characters with `0xFFFD` as recommended
per unicode spec.

Also I was curious how, exactly, UTF8 worked. Now I know, it's a pretty
reasonable spec.

## Examples

See examples folder for usage.

## Benchmarks

Current implementation based on [whatwg](https://encoding.spec.whatwg.org/#utf-8)

TODO
