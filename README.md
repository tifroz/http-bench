# http-bench

 A simplistic http benchmarking client built on node.js

## Installation

    $ npm install http-bench

## Usage

```
hb [options] <url e.g "http://www.google.com/index.html">

  Options:

    -h, --help             output usage information
    -V, --version          output the version number
    -c, --concurrency <n>  Number of concurrent clients (default: 1)
    -r, --ramp <n>         Time to ramp up clients (default: 1s)
    -t, --think <n>        Think time (default: 1s)
    -T, --timeout <n>      Request timeout (default: 60s)
    -d, --duration <n>     Test duration excluding ramp-up time and ramp-down times (default: 60s)
    -p, --partials <n>     Print partial results every n seconds (0 to disable  - this is the default)
    -v, --verbose          Verbose logs (for debugging)
```

## Output Example

```
Requests: 3009
Errors: 0
Average Time: 110ms
95 percentile: 118ms
90 percentile: 110ms
80 percentile: 107ms
70 percentile: 106ms
60 percentile: 105ms
```
Average response time in ms, includes time to connect, and time to receive the response in its entirety.

## Limitations

Supports http and https GET requests, that's about it for now.
