#! /bin/sh

set -e

zig build test

zig build bench --release=fast

./zig-out/bin/decoder_bench micro > decoder_micro.json
./zig-out/bin/decoder_bench real > decoder_real.json

./zig-out/bin/encoder_bench > encoder_micro.json

python ./bench/plot.py < decoder_micro.json
mv ./benchmark.png ./images/decoder_mirco_benchmark.png

python ./bench/plot.py < decoder_real.json
mv ./benchmark.png ./images/decoder_real_benchmark.png

python ./bench/plot.py < encoder_micro.json
mv ./benchmark.png ./images/encoder_mirco_benchmark.png
