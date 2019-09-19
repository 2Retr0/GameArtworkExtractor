@echo off
:start
set gameidline=0
set gameidlinedata=
set gameid=0

echo . . .
echo Search a Steam game title! (Make sure it's spelled correctly)

rem Input search and get the respective HTML Steam page
set /p _inputname=^> 
set webinput=%_inputname: =+%
wget --output-document %webinput%.txt https://store.steampowered.com/search/?term=%webinput%

rem Find and extract Steam game ID
echo Finding ID...
findstr /n /c:"<!-- List Items -->" %webinput%.txt >> linetemp.txt
powershell -c "$(sls '[0-9]+' linetemp.txt -allm).Matches.Value" > linetemp2.txt
for /F "delims=|" %%f in (linetemp2.txt) do set /a gameidline=%gameidline%+%%f
del linetemp.txt
del linetemp2.txt
for /F "skip=%gameidline% delims=" %%p in (%webinput%.txt) do (set gameidlinedata="%%p" & goto break)
:break
for /f "tokens=1-20 delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ/" %%a in ("%gameidlinedata:~45,15%") do set gameid=%%a%%b%%c%%d%%e%%f%%g%%h%%i%%j%%k%%l%%m%%n%%o
echo ID is %gameid%!
del %webinput%.txt
goto type

:type
echo . . .
echo Choose a type! (cover/bg/logo)
set /p inputtype=^> 
if /i "%inputtype%" equ "cover" goto cover
if /i "%inputtype%" equ "bg" goto background
if /i "%inputtype%" equ "logo" goto logo
if not defined layoutstate echo what? & goto type

:cover
rem Download game cover from SteamDB
curl https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/library_600x900_2x.jpg -o "%_inputname% cover".jpg
echo . . .
echo Done! Downloaded %_inputname% cover.jpg
goto complete

:background
rem Download background from SteamDB
curl https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/library_hero.jpg -o "%_inputname% background".jpg
echo . . .
echo Done! Downloaded %_inputname% background.jpg
goto complete

:logo
rem Download logo from SteamDB
curl https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/logo.png -o "%_inputname% logo".jpg
echo . . .
echo Done! Downloaded %_inputname% logo.jpg
goto complete 

rem Restart
:complete
goto start