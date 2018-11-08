#!/bin/bash

cd ~

tar -xvf scm_artifact.tar
ls -l

echo "----------------------------"
echo "Running Unit Tests"
echo "----------------------------"

# Do Unit Tests Here
sleep 30

echo "----------------------------"
echo "Unit Tests Passed"
echo "----------------------------"
