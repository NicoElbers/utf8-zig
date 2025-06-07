# UTF8-zig

A small and relatively fast UTF8 encoder and decoder library.

## Why

The current implementation in `std` is flawed. The `Utf8Iterator` simply
crashes on invalid inputs, and even then it's quite slow.

## Design goals

### Decoder

This implementation aims to be, in order:

1. Resilient
   - After any sequence of bytes we must return to a valid state
   - No sequence of bytes may crash the program
1. Correct
   - According to [whatwg](https://encoding.spec.whatwg.org/#utf-8-decoder)
1. Fast

### Encoder

TODO

## Benchmarks

I'm benchmarking on my AMD Ryzen 7 6800H laptop.

### Decoder

In these benchmarks, `std fixed` refers to a version of the `std`
`Utf8Iterator` which returns its errors instead of doing `catch unreachable`.
For all 3 implementations look at their respective files under `./bench/`.

Also note that between these 4 implementations, error handling behavior is
slightly different. The `utf8-zig` implementation does the most error handling,
so I don't think this ruins the benchmark. I should find better references, but
that's for later.

![Random utf8 characters](./images/perf_random_utf8_characters.png)
![Random ASCII characters](./images/perf_random_len_1_characters.png)
![Random 2 byte characters](./images/perf_random_len_2_characters.png)
![Random 3 byte characters](./images/perf_random_len_3_characters.png)
![Random 4 byte characters](./images/perf_random_len_4_characters.png)

### Encoder

TODO

## Examples

See examples folder for usage.
