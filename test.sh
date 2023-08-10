#!/bin/bash

set -e

flow test --cover --coverprofile="coverage.lcov" ./test/*_tests.cdc