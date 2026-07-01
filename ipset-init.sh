#!/bin/bash

ipset create knock1 hash:ip timeout 2 -exist
ipset create knock2 hash:ip timeout 2 -exist
ipset create knock_allowed hash:ip timeout 60 -exist
