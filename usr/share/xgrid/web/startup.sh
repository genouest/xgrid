#!/bin/bash
cd /usr/share/xgrid/web
rackup -E production -p 4567 -o 0.0.0.0
