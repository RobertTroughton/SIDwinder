@echo off
setlocal enabledelayedexpansion

:: Initialize counters
set success_count=0
set fail_count=0
set total_count=0

set logfile=relocations.log
if exist "%logfile%" del "%logfile%"

mkdir Reloc 2>nul

@echo ---------------
@echo Relocating SIDs
@echo ---------------
@echo.
@echo Logging to: %logfile%
@echo.

@echo --------------- >> "%logfile%"
@echo Relocating SIDs >> "%logfile%"
@echo --------------- >> "%logfile%"
@echo. >> "%logfile%"

:: Function to relocate and count results
goto :start

:relocate

set /a total_count+=1
set input_file=%~1
set output_file=%~2
set filename=%~nx1

:: Create a temporary file for this command's output
set tempfile=temp_%random%.txt

:: Run the command and capture both stdout and stderr
SIDwinder.exe -relocate -relocateaddr=$2000 "%input_file%" "%output_file%" > "%tempfile%" 2>&1
set exitcode=!errorlevel!

:: Display and log the output
type "%tempfile%"
type "%tempfile%" >> "%logfile%"

:: Check result
if !exitcode! equ 0 (
    set /a success_count+=1
) else (
    set /a fail_count+=1
)

:: Clean up temp file
del "%tempfile%" >nul 2>&1

goto :eof

:start

:: Process all SID files
call :relocate "SID/trident-cheap.sid" "Reloc/rel2000-trident-cheap.sid"

call :relocate "SID/larshoff-recovery.sid" "Reloc/rel2000-larshoff-recovery.sid"
call :relocate "SID/celticdesign-7-3.sid" "Reloc/rel2000-celticdesign-7-3.sid"
call :relocate "SID/larshoff-blades.sid" "Reloc/rel2000-larshoff-blades.sid"
call :relocate "SID/dane-copperbooze.sid" "Reloc/rel2000-dane-copperbooze.sid"
call :relocate "SID/dane-elderscrollers.sid" "Reloc/rel2000-dane-elderscrollers.sid"
call :relocate "SID/dane-slowmotionsong.sid" "Reloc/rel2000-dane-slowmotionsong.sid"
call :relocate "SID/drax-expand.sid" "Reloc/rel2000-drax-expand.sid"
call :relocate "SID/drax-twine.sid" "Reloc/rel2000-drax-twine.sid"
call :relocate "SID/flex-eurogubbe.sid" "Reloc/rel2000-flex-eurogubbe.sid"
call :relocate "SID/flex-hawkeye.sid" "Reloc/rel2000-flex-hawkeye.sid"
call :relocate "SID/Flex-lundia.sid" "Reloc/rel2000-Flex-lundia.sid"
call :relocate "SID/jammer-mm.sid" "Reloc/rel2000-jammer-mm.sid"
call :relocate "SID/jammer-soccer.sid" "Reloc/rel2000-jammer-soccer.sid"
call :relocate "SID/jch-allaroundtheworld.sid" "Reloc/rel2000-jch-allaroundtheworld.sid"
call :relocate "SID/jch-crystalline.sid" "Reloc/rel2000-jch-crystalline.sid"
call :relocate "SID/leaf-takeitorleafit.sid" "Reloc/rel2000-leaf-takeitorleafit.sid"
call :relocate "SID/lukhash-codeveronica.sid" "Reloc/rel2000-lukhash-codeveronica.sid"
call :relocate "SID/magnar-airwolf.sid" "Reloc/rel2000-magnar-airwolf.sid"
call :relocate "SID/magnar-firestarter.sid" "Reloc/rel2000-magnar-firestarter.sid"
call :relocate "SID/magnar-lastnight.sid" "Reloc/rel2000-magnar-lastnight.sid"
call :relocate "SID/magnar-magnumpi.sid" "Reloc/rel2000-magnar-magnumpi.sid"
call :relocate "SID/magnar-wecomeinpeace.sid" "Reloc/rel2000-magnar-wecomeinpeace.sid"
call :relocate "SID/magnar-wonderland12.sid" "Reloc/rel2000-magnar-wonderland12.sid"
call :relocate "SID/mch-chordexplorer.sid" "Reloc/rel2000-mch-chordexplorer.sid"
call :relocate "SID/mch-montyontherundnbedit-2sid.sid" "Reloc/rel2000-mch-montyontherundnbedit-2sid.sid"
call :relocate "SID/mibri-gettinginthevan.sid" "Reloc/rel2000-mibri-gettinginthevan.sid"
call :relocate "SID/mrmouse-downhill.sid" "Reloc/rel2000-mrmouse-downhill.sid"
call :relocate "SID/nordischsound-crockettstheme.sid" "Reloc/rel2000-nordischsound-crockettstheme.sid"
call :relocate "SID/phat_frog_2sid.sid" "Reloc/rel2000-phat_frog_2sid.sid"
call :relocate "SID/proton-knightrider.sid" "Reloc/rel2000-proton-knightrider.sid"
call :relocate "SID/psycho-nobounds.sid" "Reloc/rel2000-psycho-nobounds.sid"
call :relocate "SID/steel-92littleshortyrockers.sid" "Reloc/rel2000-steel-92littleshortyrockers.sid"
call :relocate "SID/steel-lastnightdrunk.sid" "Reloc/rel2000-steel-lastnightdrunk.sid"
call :relocate "SID/steelstinsen-dangerdawg.sid" "Reloc/rel2000-steelstinsen-dangerdawg.sid"
call :relocate "SID/stinsen-diagonality.sid" "Reloc/rel2000-stinsen-diagonality.sid"
call :relocate "SID/stinsenleaf-pushthrough.sid" "Reloc/rel2000-stinsenleaf-pushthrough.sid"
call :relocate "SID/stinsen-onborrowedwings.sid" "Reloc/rel2000-stinsen-onborrowedwings.sid"
call :relocate "SID/toggle-fireflies.sid" "Reloc/rel2000-toggle-fireflies.sid"
call :relocate "SID/trident-elysoun.sid" "Reloc/rel2000-trident-elysoun.sid"
call :relocate "SID/trident-sptest07.sid" "Reloc/rel2000-trident-sptest07.sid"
call :relocate "SID/xiny-allstars.sid" "Reloc/rel2000-xiny-allstars.sid"
call :relocate "SID/xiny-splashes.sid" "Reloc/rel2000-xiny-splashes.sid"
call :relocate "SID/zardax-eldorado.sid" "Reloc/rel2000-zardax-eldorado.sid"
call :relocate "SID/6r6-axelf.sid" "Reloc/rel2000-6r6-axelf.sid"
call :relocate "SID/6r6-selfiesfromtheex.sid" "Reloc/rel2000-6r6-selfiesfromtheex.sid"
call :relocate "SID/acrouzet-raistlin50.sid" "Reloc/rel2000-acrouzet-raistlin50.sid"
call :relocate "SID/acrouzet-soulspace.sid" "Reloc/rel2000-acrouzet-soulspace.sid"
call :relocate "SID/celticdesign-blueearth.sid" "Reloc/rel2000-celticdesign-blueearth.sid"

:: Display results
@echo.
@echo ========================================
@echo RELOCATION RESULTS
@echo ========================================
@echo.
@echo !success_count!/!total_count! relocations succeeded

@echo. >> "%logfile%"
@echo ======================================== >> "%logfile%"
@echo RELOCATION RESULTS >> "%logfile%"
@echo ======================================== >> "%logfile%"
@echo. >> "%logfile%"
@echo !success_count!/!total_count! relocations succeeded >> "%logfile%"

@pause