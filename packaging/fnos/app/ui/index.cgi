#!/bin/bash

echo "Content-Type: text/html; charset=utf-8"
echo "Cache-Control: no-store"
echo ""
cat "/var/apps/chatmock-fnos/target/www/index.html"
