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
    -c, --concurrency <n>  Number of concurrent clients (default: 1)
```

## Output

```
Requests: 2213
Errors: 0
Avg Time: 2110
``
Average response time in ms, includes time to connect, and time to receive the entire response.
