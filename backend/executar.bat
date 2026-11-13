@echo off
chcp 65001 >nul
cd /d "%~dp0"
if exist out rmdir /s /q out
dir /s /b src\*.java > fontes.txt
javac -encoding UTF-8 -cp lib\mysql-connector-j-26.10.0.jar -d out @fontes.txt
if errorlevel 1 goto fim
del fontes.txt
java -Dstdout.encoding=UTF-8 -cp "out;lib\mysql-connector-j-26.10.0.jar" academia.Main
:fim
pause
