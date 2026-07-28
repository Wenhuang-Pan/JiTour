@echo off
keytool -genkey -v -keystore android\app\jitu.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias jitu ^
  -dname "CN=记途,OU=个人记账,O=Jitu,L=Shanghai,S=Shanghai,C=CN" ^
  -storepass Jitu2026 ^
  -keypass Jitu2026
