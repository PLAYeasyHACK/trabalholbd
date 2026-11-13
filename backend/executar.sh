#!/bin/sh
cd "$(dirname "$0")"
rm -rf out
javac -encoding UTF-8 -cp lib/mysql-connector-j-26.10.0.jar -d out $(find src -name '*.java') || exit 1
java -Dstdout.encoding=UTF-8 -cp "out:lib/mysql-connector-j-26.10.0.jar" academia.Main
