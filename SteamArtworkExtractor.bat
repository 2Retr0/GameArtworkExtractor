@echo off
:: we need to change the active code page to UTF-8 to allow for uncommon cases of special characters in game titles
chcp 65001
echo .
echo SteamArtworkExtractor by me!

:start
    echo . . .
    echo Search a Steam game title! (or type 'manual' for ID input)

    :: choose what search input should be used
    set /p _inputname=^> 
    if /i "%_inputname%" equ "exit" exit
    if /i "%_inputname%" equ "manual" goto manualsearch else goto namedsearch
    
:namedsearch
    :: find and extract Steam game ID
    :: replace all spaces in inputted name with plus signs for input into the steam store serach engine
    set webinput=%_inputname: =+%
    :: download the steam search webpage as a txt file with the inputted name as the search
    wget -q --output-document %webinput%.txt https://store.steampowered.com/search/?term=%webinput%
    
    :: check for a specific string that determines if the search returned nothing
    findstr /c:"0 results match your search." %webinput%.txt > nul 2>&1
    :: if so, return to the start
    if %errorlevel%==0 (
        del %webinput%.txt
        echo Couldn't find the game :/
        goto start
    )
    
    :: gametitle
    :: find the line number that has the game title within the downloaded webpage txt file
    for /f "tokens=1 delims=:" %%i in ('findstr /n /c:"class=\"title\"" %webinput%.txt') do set /a gametitleloc=%%i-1 & goto break1
    :: labels are used as breaks in for commands as I don't know another way
    :break1
    :: isolate the game title from the line
    for /f "skip=%gametitleloc% tokens=3 delims=<>" %%i in (%webinput%.txt) do set gametitle=%%i & goto break2
    :break2
    :: remove colons from game titles as they cannot be used in a filename
    set gametitle=%gametitle::=%

    :: gameid
    :: find the line number that has the game id within the downloaded webpage txt file
    for /f "tokens=1 delims=:" %%i in ('findstr /n /c:"<!-- List Items -->" %webinput%.txt') do set /a gameidloc=%%i
    :: isolate the game id from the line
    for /f "skip=%gameidloc% tokens=4 delims=/" %%i in (%webinput%.txt) do set /a gameid=%%i & goto break3
    :break3
    del %webinput%.txt
    echo ID for %gametitle%is %gameid%!
    goto format

:manualsearch
    echo . . .
    echo Manual mode!
    echo Enter a Steam game ID or type 'exit' to restart...
    set /p _inputid=^> 
    if /i "%_inputid%" equ "exit" goto start
    :: check if input is numeric in value
    for /f "delims=0123456789" %%i in ("%_inputid%") do set inputcheck=%%i
    if defined inputcheck echo %_inputid% is not numeric! & goto manualsearch

    :: download steam store webpage with the inputted id
    wget -q --output-document %_inputid%.txt https://store.steampowered.com/app/%_inputid%/
    :: check if the downloaded file is larger than 250kb in size
    :: if it is, we most likely downloaded the steam store front page meaning a steam store page with the inputted id most likely does not exist
    for /f %%i in ("%_inputid%.txt") do set size=%%~zi
    if %size% gtr 250 (
        del %_inputid%.txt
        echo Could not find a game with ID %_inputid%! :/
        goto manualsearch
    )
    :: find the line number that has the game title within the downloaded webpage txt file
    for /f "tokens=1 delims=:" %%i in ('findstr /n /c:"apphub_AppName" %_inputid%.txt') do set /a gametitleloc=%%i-1
    :: isolate the game title from the line
    for /f "skip=%gametitleloc% tokens=3 delims=<>" %%i in (%_inputid%.txt) do set gametitle=%%i & goto break4
    :break4
    del %_inputid%.txt
    echo Found %gametitle%!
    set gameid=%_inputid%

:format
    :: select between game cover, background, or logo
    echo . . .
    echo Choose a format! (cover/bg/logo)
    set /p _inputformat=^> 
    if /i "%_inputformat%" equ "exit" goto start
    if /i "%_inputformat%" equ "cover" goto cover
    if /i "%_inputformat%" equ "bg" goto background
    if /i "%_inputformat%" equ "logo" goto logo
    if not defined layoutstate echo What? & goto format

:cover
    :: download the webpage for the cover image
    wget -q --output-document %webinput%cover.txt https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/library_600x900_2x.jpg
    :: if the size of the page is 0kb, the image does not exist
    for /f %%i in ("%webinput%cover.txt") do set size=%%~zi
    if %size% equ 0 (
        del %webinput%cover.txt
        echo This game doesn't appear to have a cover image :/
        goto start
    )
    del %webinput%cover.txt
    
    :: download game cover from steam
    curl -s https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/library_600x900_2x.jpg -o "%gametitle%cover".jpg
    echo Downloaded %gametitle%cover.jpg!
    goto start

:background
    :: download the webpage for the background image
    wget -q --output-document %webinput%bg.txt https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/library_hero.jpg
    for /f %%i in ("%webinput%bg.txt") do set size=%%~zi
    if %size% equ 0 (
        del %webinput%bg.txt
        echo This game doesn't appear to have a background image :/
        goto start
    )
    del %webinput%bg.txt
    
    :: download background from steam
    curl -s https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/library_hero.jpg -o "%gametitle%background".jpg
    echo Downloaded %gametitle%background.jpg!
    goto start

:logo
    :: download the webpage for the logo image
    wget -q --output-document %webinput%logo.txt https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/logo.png
    for /f %%i in ("%webinput%logo.txt") do set size=%%~zi
    if %size% equ 0 (
        del %webinput%logo.txt
        echo This game doesn't appear to have a logo image :/
        goto start
    )
    del %webinput%logo.txt
    
    :: download logo from steam
    curl -s https://steamcdn-a.akamaihd.net/steam/apps/%gameid%/logo.png -o "%gametitle%logo".jpg
    echo Downloaded %gametitle%logo.jpg!
    goto start