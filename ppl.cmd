if exist "%~dp0.git\index.lock" del "%~dp0.git\index.lock"

git pull

git config --global user.name veretennikovalexey
git config --global user.email raidex@yandex.ru

git add .
git commit -m alex
git push origin main

rem pause