@echo off

mkdir Examples

SIDwinder.exe -relocate -relocateaddr=$1000 SID/celticdesign-7-3.sid temp/celticdesign-7-3-rel1000.sid

REM VISUALISER doesn't work?? -- SIDwinder.exe -player=RaistlinBarsWithLogo -define LogoKoala="../../Logos/facet-mrmouse.kla" SID/mrmouse-downhill.sid examples/mrmouse-downhill.prg

REM Raistlin Bars With Musician's Provided Logo
SIDwinder.exe -player=RaistlinBarsWithLogo -define LogoKoala="../../Logos/facet-acrouzet.kla" SID/acrouzet-raistlin50.sid examples/acrouzet-raistlin50.prg
SIDwinder.exe -player=RaistlinBarsWithLogo -define LogoKoala="../../Logos/redcrab-celticdesign.kla" temp/celticdesign-7-3-rel1000.sid examples/celticdesign-7-3.prg
SIDwinder.exe -player=RaistlinBarsWithLogo -define LogoKoala="../../Logos/redcrab-leaf.kla" SID/leaf-takeitorleafit.sid examples/leaf-takeitorleafit.prg
SIDwinder.exe -player=RaistlinBarsWithLogo -define LogoKoala="../../Logos/facet-mch.kla" SID/mch-montyontherundnbedit-2sid.sid examples/mch-montyontherundnbedit-2sid.prg
SIDwinder.exe -player=RaistlinBarsWithLogo -define LogoKoala="../../Logos/facet-psych858o.kla" SID/psycho-nobounds.sid examples/psycho-nobounds.prg
SIDwinder.exe -player=RaistlinBarsWithLogo -define LogoKoala="../../Logos/redcrab-steel2.kla" SID/steel-lastnightdrunk.sid examples/steel-lastnightdrunk.prg
SIDwinder.exe -player=RaistlinBarsWithLogo -define LogoKoala="../../Logos/redcrab-stinsen.kla" SID/stinsen-onborrowedwings.sid examples/stinsen-onborrowedwings.prg
SIDwinder.exe -player=RaistlinBarsWithLogo -define LogoKoala="../../Logos/redcrab-stinsensteel.kla" SID/steelstinsen-dangerdawg.sid examples/steelstinsen-dangerdawg.prg

REM Raistlin Bars With Default Logo
SIDwinder.exe -player=RaistlinBarsWithLogo SID/dane-copperbooze.sid examples/dane-copperbooze.prg
SIDwinder.exe -player=RaistlinBarsWithLogo SID/jammer-soccer.sid examples/jammer-soccer.prg
SIDwinder.exe -player=RaistlinBarsWithLogo SID/jch-allaroundtheworld.sid examples/jch-allaroundtheworld.prg
SIDwinder.exe -player=RaistlinBarsWithLogo SID/magnar-firestarter.sid examples/magnar-firestarter.prg
SIDwinder.exe -player=RaistlinBarsWithLogo SID/xiny-allstars.sid examples/xiny-allstars.prg

REM Raistlin Mirror Bars With Musician's Provided Logo
SIDwinder.exe -player=RaistlinMirrorBarsWithLogo -define LogoKoala="../../Logos/facet-acrouzet.kla" SID/acrouzet-soulspace.sid examples/acrouzet-soulspace.prg
SIDwinder.exe -player=RaistlinMirrorBarsWithLogo -define LogoKoala="../../Logos/redcrab-celticdesign2.kla" SID/celticdesign-blueearth.sid examples/celticdesign-blueearth.prg
SIDwinder.exe -player=RaistlinMirrorBarsWithLogo -define LogoKoala="../../Logos/redcrab-mch.kla" SID/mch-chordexplorer.sid examples/mch-chordexplorer.prg
SIDwinder.exe -player=RaistlinMirrorBarsWithLogo -define LogoKoala="../../Logos/redcrab-steel.kla" SID/steel-92littleshortyrockers.sid examples/steel-92littlefshortyrockers.prg
SIDwinder.exe -player=RaistlinMirrorBarsWithLogo -define LogoKoala="../../Logos/facet-stinsen.kla" SID/stinsen-diagonality.sid examples/stinsen-diagonality.prg

REM Raistlin Mirror Bars With Default Logo
SIDwinder.exe -player=RaistlinMirrorBarsWithLogo SID/drax-expand.sid examples/drax-expand.prg
SIDwinder.exe -player=RaistlinMirrorBarsWithLogo SID/jch-crystalline.sid examples/jch-crystalline.prg
SIDwinder.exe -player=RaistlinMirrorBarsWithLogo SID/magnar-wonderland12.sid examples/magnar-wonderland12.prg

REM Simple Raster
SIDwinder.exe -player=SimpleRaster SID/jammer-mm.sid examples/jammer-mm.prg
SIDwinder.exe -player=SimpleRaster SID/magnar-airwolf.sid examples/magnar-airwolf.prg
SIDwinder.exe -player=SimpleRaster SID/toggle-fireflies.sid examples/toggle-fireflies.prg

REM Raistlin Bars
SIDwinder.exe -player=RaistlinBars SID/dane-elderscrollers.sid examples/dane-elderscrollers.prg
SIDwinder.exe -player=RaistlinBars SID/dane-slowmotionsong.sid examples/dane-slowmotionsong.prg
SIDwinder.exe -player=RaistlinBars SID/drax-twine.sid examples/drax-twine.prg
SIDwinder.exe -player=RaistlinBars SID/flex-eurogubbe.sid examples/flex-eurogubbe.prg
SIDwinder.exe -player=RaistlinBars SID/flex-hawkeye.sid examples/flex-hawkeye.prg
SIDwinder.exe -player=RaistlinBars SID/flex-lundia.sid examples/flex-lundia.prg
SIDwinder.exe -player=RaistlinBars SID/magnar-lastnight.sid examples/magnar-lastnight.prg
SIDwinder.exe -player=RaistlinBars SID/magnar-magnumpi.sid examples/magnar-magnumpi.prg
SIDwinder.exe -player=RaistlinBars SID/magnar-wecomeinpeace.sid examples/magnar-wecomeinpeace.prg
SIDwinder.exe -player=RaistlinBars SID/mibri-gettinginthevan.sid examples/mibri-gettinginthevan.prg
SIDwinder.exe -player=RaistlinBars SID/nordischsound-crockettstheme.sid examples/nordischsound-crockettstheme.prg
SIDwinder.exe -player=RaistlinBars SID/phat_frog_2sid.sid examples/phat_frog_2sid.prg
SIDwinder.exe -player=RaistlinBars SID/proton-knightrider.sid examples/proton-knightrider.prg
SIDwinder.exe -player=RaistlinBars SID/stinsenleaf-pushthrough.sid examples/stinsenleaf-pushthrough.prg
SIDwinder.exe -player=RaistlinBars SID/trident-sptest07.sid examples/trident-sptest07.prg
SIDwinder.exe -player=RaistlinBars SID/xiny-splashes.sid examples/xiny-splashes.prg
SIDwinder.exe -player=RaistlinBars SID/zardax-eldorado.sid examples/zardax-eldorado.prg

@pause