#!/bin/bash -e
# Copyright 2023 WSO2 LLC. (http://wso2.org)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ----------------------------------------------------------------------------
# Pre run script for ballerina performance tests
# ----------------------------------------------------------------------------
set -e
source base-scenario.sh

echo "----------Pick WS Next responses from jtl----------"
# 'WS Next' is the lable of the WS sampler in JMeter
grep -E 'WS Next|label' "${resultsDir}/"original.jtl > "${resultsDir}/".temp.jtl
rm "${resultsDir}/"original.jtl
mv "${resultsDir}/".temp.jtl "${resultsDir}/"original.jtl

echo "----------Modified original.jtl----------"
tail -5 "${resultsDir}/original.jtl"
echo "----------End jtl----------"

echo "--------Processing Results--------"
# pushd "${REPO_NAME}"/load-tests/"${SCENARIO_NAME}"/results/
echo "--------Splitting Results--------"
jtl-splitter.sh -- -f original.jtl -t 120 -u SECONDS -s
ls -ltr
echo "--------Splitting Completed--------"

echo "--------Generating CSV--------"
sudo chmod +x $JMETER_HOME/bin/JMeterPluginsCMD.sh
JMeterPluginsCMD.sh --generate-csv temp_summary.csv --input-jtl original-measurement.jtl --plugin-type AggregateReport
echo "--------CSV generated--------"

echo "--------Merge CSV--------"
create-csv.sh temp_summary.csv /home/ballerina/"${REPO_NAME}"/load-tests/"${SCENARIO_NAME}"/results/summary.csv "${payload_size}" "${concurrent_users}"
echo "--------CSV merged--------"
# popd
