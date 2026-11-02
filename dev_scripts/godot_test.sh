#!/bin/sh
# Запуск тестового Godot так, щоб НІЧОГО не писалось на диск C:.
# Без цього user:// (save.json, логи, кеш шейдерів) іде в
# C:\Users\...\AppData\Roaming\Godot\app_userdata\Rune Horde — туди ж,
# де лежить сейв гри з редактора користувача.
W='D:\RuneHorde_work\test_appdata'
export APPDATA="$W\Roaming"
export LOCALAPPDATA="$W\Local"
export TEMP="$W\Temp"
export TMP="$W\Temp"
exec /d/RuneHorde_work/godot_tests/Godot_v4.7.2-stable_win64_console.exe --path /d/RuneHorde_work/test_env "$@"
