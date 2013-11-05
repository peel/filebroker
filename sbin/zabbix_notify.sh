#!/bin/bash
while read line; do
  var=$(echo ${line} | cut -d' ' -f5-)
  /tech/nordea/common/bin/log2zbx.pl --host "`hostname`" --err --msg "${var}"
done