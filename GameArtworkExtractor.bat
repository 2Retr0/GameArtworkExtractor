@echo off
:: we need to change the active code page to UTF-8 to allow for uncommon cases of special characters in game titles
chcp 65001 > nul 2>&1
echo GameArtworkExtractor by 2Retr0!

:: set up requesies folder and download prerequesites
if not exist requesites (mkdir requesites)
cd requesites
if not exist wget.exe (
    echo Downloading wget...
    curl -s https://eternallybored.org/misc/wget/1.20.3/64/wget.exe -o wget.exe
    if errorlevel 1 goto downloadfail
)
if not exist jq.exe (
    echo Downloading jq...
    curl -s -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe -o jq.exe
    if errorlevel 1 goto downloadfail
)
cd ..

:start
    echo . . .
    echo Choose a platform to extract game art! (steam/twitch)
    :: choose what type of platform should be used
    set /p _inputplatform=^> 
    if /i "%_inputplatform%" equ "exit" exit
    if /i "%_inputplatform%" equ "steam" goto steamstart
    if /i "%_inputplatform%" equ "twitch" goto twitchsearch
    if not defined layoutstate echo Come again? & goto start

:twitchsearch
    echo . . .
    echo Search a game title!
    set /p _inputname=^> 
    setlocal EnableDelayedExpansion
    :: replace space characters with "%20" for web search
    set "_webinput=!_inputname: =%%20!"
    cd requesites
    :: search for the game using the twitch dev API
    :: since the command will output into a single line, we need to pipe it using jq.exe to format the JSON correctly into a text file
    curl -s -H "Accept:application/vnd.twitchtv.v5+json" -H "Client-ID:b9ocq1yvlok4fh77ftqa6d5nk1tk7x" -X GET "https://api.twitch.tv/kraken/search/games?query=%_webinput%" | jq "" > %~dp0/query.txt
    endlocal
    :: check if a game is found, if not goto twitchsearch
    findstr /m ""games": null" query.txt > nul
    if %errorlevel%==0 (
        del query.txt
        echo Couldn't find a game :/
        goto twitchsearch
    )

    :: extract the leading game title from the text file we created
    for /f "skip=19 delims=" %%i in (query.txt) do set gametitle=%%i & goto twitchbreak1
    :twitchbreak1
    set gametitle=%gametitle:~25,-3%
    echo Found %gametitle%!

    :: extract the generic URL for the game's cover
    :: even if it doesn't exist, we will still copy it for now
    for /f "skip=11 delims=" %%i in (query.txt) do set gamecoverurl=%%i & goto twitchbreak2
    :twitchbreak2
    :: substring the URL and append a high resolution format
    set gamecoverurl=%gamecoverurl:~21,-22%1440x1920.jpg

    :: extract the generic URL for the game's logo 
    for /f "skip=17 delims=" %%i in (query.txt) do set gamelogourl=%%i & goto twitchbreak3
    :twitchbreak3
    :: substring the URL and append a high resolution format
    set gamelogourl=%gamelogourl:~21,-22%2400x1440.jpg
    del query.txt
    goto twitchformat

:twitchformat
    :: select between game cover or logo
    echo . . .
    echo Choose a format! (cover/logo)
    set /p _inputformat=^> 
    if /i "%_inputformat%" equ "exit" goto start
    if /i "%_inputformat%" equ "cover" goto twitchcover
    if /i "%_inputformat%" equ "logo" goto twitchlogo
    if not defined layoutstate echo Hmm? & goto twitchformat

:twitchcover
    :: download the game cover image
    curl -s %gamecoverurl% -o "twitchcover_%gametitle%".jpg
    :: if it does not exist, the size of the file should be less than 150b, and from this, we can determine that a cover does not exist
    for %%i in ("twitchcover_%gametitle%.jpg") do set size=%%~zi
    if %size% lss 150 (
        del "twitchcover_%gametitle%.jpg"
        echo This game doesn't appear to have a cover image :/
        goto start
    )
    echo Downloaded twitchcover_%gametitle%.jpg!
    goto start

:twitchlogo
    :: download the game logo image
    curl -s %gamelogourl% -o "twitchlogo_%gametitle%".jpg
    :: same process as in :twitchcover is used to determine if a logo image doesn't exist
    for %%i in ("twitchlogo_%gametitle%.jpg") do set size=%%~zi
    if %size% lss 150 (
        del "twitchlogo_%gametitle%.jpg"
        echo This game doesn't appear to have a logo image :/
        goto start
    )
    echo Downloaded twitchlogo_%gametitle%.jpg!
    goto start

:steamstart
    echo . . .
    echo Search a Steam game title! (or type 'manual' for ID input)

    :: choose what type of search input should be used
    set /p _inputname=^> 
    if /i "%_inputname%" equ "exit" goto start
    if /i "%_inputname%" equ "manual" goto steammanualsearch else goto steamnamedsearch
    
:steamnamedsearch
    :: find and extract Steam game ID
    :: replace all spaces in inputted name with plus signs for input into the steam store serach engine
    set webinput=%_inputname: =+%
    :: download the steam search webpage as a txt file with the inputted name as the search
    cd requesites
    wget -q --output-document %~dp0/%webinput%.txt https://store.steampowered.com/search/?term=%webinput%
    cd ..
    
    :: check for a specific string that determines if the search returned nothing
    findstr /c:"0 results match your search." %webinput%.txt > nul 2>&1
    :: if so, return to the start
    if %errorlevel%==0 (
        del %webinput%.txt
        echo Couldn't find the game :/
        goto steamstart
    )
    
    :: gametitle
    :: find the line number that has the game title within the downloaded webpage txt file
    for /f "tokens=1 delims=:" %%i in ('findstr /n /c:"class=\"title\"" %webinput%.txt') do set /a gametitleloc=%%i-1 & goto steambreak1
    :: labels are used as breaks in for commands as I don't know another way
    :steambreak1
    :: isolate the game title from the line
    for /f "skip=%gametitleloc% tokens=3 delims=<>" %%i in (%webinput%.txt) do set gametitle=%%i & goto steambreak2
    :steambreak2
    :: remove colons from game titles as they cannot be used in a filename
    set gametitle=%gametitle::=%
    :: remove trailing space character from game title
    set gametitle=%gametitle:~0,-1%

    :: gameid
    :: find the line number that has the game id within the downloaded webpage txt file
    for /f "tokens=1 delims=:" %%i in ('findstr /n /c:"<!-- List Items -->" %webinput%.txt') do set /a gameidloc=%%i
    :: isolate the game id from the line
    for /f "skip=%gameidloc% tokens=4 delims=/" %%i in (%webinput%.txt) do set /a gameid=%%i & goto steambreak3
    :steambreak3
    del %webinput%.txt
    echo ID for %gametitle% is %gameid%!
    goto steamformat

:steammanualsearch
    set inputcheck=
    echo . . .
    echo Manual mode!
    echo Enter a Steam game ID or type 'exit' to restart...
    set /p _inputid=^> 
    if /i "%_inputid%" equ "exit" goto start
    :: check if input is numeric in value
    for /f "delims=0123456789" %%i in ("%_inputid%") do set inputcheck=%%i
    if defined inputcheck echo %_inputid% is not numeric! & goto steammanualsearch

    :: download steam store webpage with the inputted id
    cd requesites
    wget -q --output-document %~dp0/%_inputid%.txt https://store.steampowered.com/app/%_inputid%/
    cd ..
    :: check if the downloaded file is larger than 250kb in size
    :: if it is, we most likely downloaded the steam store front page meaning a steam store page with the inputted id most likely does not exist
    for %%i in ("%_inputid%.txt") do set size=%%~zi
    if %size% gtr 250000 (
        del %_inputid%.txt
        echo Could not find a game with ID %_inputid%! :/
        goto steammanualsearch
    )
    :: find the line number that has the game title within the downloaded webpage txt file
    for /f "tokens=1 delims=:" %%i in ('findstr /n /c:"apphub_AppName" %_inputid%.txt') do set /a gametitleloc=%%i-1
    :: isolate the game title from the line
    for /f "skip=%gametitleloc% tokens=3 delims=<>" %%i in (%_inputid%.txt) do set gametitle=%%i & goto steambreak4
    :steambreak4
    :: remove trailing space character from game title
    set gametitle=%gametitle:~0,-1%
    del %_inputid%.txt
    echo Found %gametitle%!
    set gameid=%_inputid%

:steamformat
    :: select between game cover, background, or logo
    echo . . .
    echo Choose a format! (cover/bg/logo)
    set /p _inputformat=^> 
    if /i "%_inputformat%" equ "exit" goto start
    if /i "%_inputformat%" equ "cover" goto steamcover
    if /i "%_inputformat%" equ "bg" goto steambackground
    if /i "%_inputformat%" equ "logo" goto steamlogo
    if not defined layoutstate echo What? & goto steamformat

:steamcover
    :: download the webpage for the cover image
    cd requesites
    wget -q --output-document %~dp0/%webinput%cover.txt https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/library_600x900_2x.jpg
    cd ..
    :: if the size of the page is 0kb, the image does not exist
    for %%i in ("%webinput%cover.txt") do set size=%%~zi
    if %size% equ 0 (
        del %webinput%cover.txt
        echo This game doesn't appear to have a cover image :/
        goto start
    )
    del %webinput%cover.txt
    
    :: download game cover from steam
    curl -s https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/library_600x900_2x.jpg -o "steamcover_%gametitle%".jpg
    echo Downloaded steamcover_%gametitle%.jpg!
    goto start

:steambackground
    :: download the webpage for the background image
    cd requesites
    wget -q --output-document %~dp0/%webinput%bg.txt https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/library_hero.jpg
    cd ..
    for %%i in ("%webinput%bg.txt") do set size=%%~zi
    if %size% equ 0 (
        del %webinput%bg.txt
        echo This game doesn't appear to have a background image :/
        goto start
    )
    del %webinput%bg.txt
    
    :: download background from steam
    curl -s https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/library_hero.jpg -o "steambg_%gametitle%".jpg
    echo Downloaded steambg_%gametitle%.jpg!
    goto start

:steamlogo
    :: download the webpage for the logo image
    cd requesites
    wget -q --output-document %~dp0/%webinput%logo.txt https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/logo.png
    cd ..
    for %%i in ("%webinput%logo.txt") do set size=%%~zi
    if %size% equ 0 (
        del %webinput%logo.txt
        echo This game doesn't appear to have a logo image :/
        goto start
    )
    del %webinput%logo.txt
    
    :: download logo from steam
    curl -s https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/logo.png -o "steamlogo_%gametitle%".jpg
    echo Downloaded steamlogo_%gametitle%.jpg!
    goto start

:downloadfail
    echo . . .
    echo Download failed, something went wrong... Press any key to close this window.
    pause > nul