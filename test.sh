#!/bin/bash

set -e

flow-c1 test --cover --covercode="contracts" --coverprofile="coverage.lcov" test/*_tests.cdc