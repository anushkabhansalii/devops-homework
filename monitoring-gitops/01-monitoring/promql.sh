#!/bin/bash
# Run a PromQL query against Prometheus (port-forwarded to localhost:9090) and print one line per series.
# Usage: ./promql.sh '<query>'
q="$1"
curl -s "http://localhost:9090/api/v1/query" --data-urlencode "query=$q" \
  | jq -r '.data.result[] | "\(.metric.deployment // .metric.pod // .metric.job // .metric.__name__ // "value")\t\(.value[1] | tonumber | . * 1000 | round / 1000)"' \
  | column -t -s $'\t'
