# Privaatsus

Korrutaja on tehtud nii, et tal poleks midagi, mida lekitada.

## Mida hoitakse telefonis

Brauseri kohalikus mälus (localStorage) sellel seadmel:

- iga korrutus- ja jagamisfakti vastuste ajalugu (õige/vale, aeg), viimased 10;
- päevade loendur, Kontrolli tulemused, seaded (nimi, taimer, režiim);
- klassiga liitumisel: klassi kood, hüüdnimi ja mängija salakood (taastekood).

Kustutamine: Seaded → „Kustuta kõik andmed“, või brauseri saidiandmete kustutamine.

## Mida hoitakse serveris

Ainult siis, kui laps on liitunud klassiga. Server on Supabase, andmekeskus Euroopa Liidus (Frankfurt).

- klass: nimi (nt „3B Kesklinna kool“), 6-märgiline kood;
- mängija: hüüdnimi, salakood, roheliste faktide arv, parim Kontroll, vastuste summad, ja edenemise koopia (sama, mis telefonis) telefoni vahetuseks;
- iga ring: mitu küsimust, mitu õiget, punktid, keskmine aeg, aeg.

**Ei hoita:** päris nime, e-posti, telefoninumbrit, asukohta, IP-aadressi püsivalt, seadme andmeid, küpsiseid.

## Mida ei ole

Reklaami, analüütikat (Google Analytics vms), jälgimispiksleid, sotsiaalmeedia nuppe, kolmandate osapoolte skripte. Ainus väline päring peale Supabase'i on kirjatüüpide laadimine Google Fontsist (fonts.googleapis.com); see kannab tavalist HTTP-päringut ja mitte midagi mängu kohta.

## Kes näeb mida

- Sama klassi liikmed näevad üksteise hüüdnime ja vastuste arve edetabelis.
- Teised klassid näevad klassi nime ja nädala keskmist, mitte lapsi.
- Tegija (Silver Jaanus) näeb andmebaasi toorelt, et hoida asja töös.

## Kustutamine serverist

Seaded → Klass → „Lahku“ katkestab seose telefonis; serverikirje kustutamiseks kirjuta silverjaanus.com kaudu, ütle klassikood ja hüüdnimi. Klassid, kus pole aasta jooksul kedagi harjutanud, võidakse kustutada.

## Lapsed

Mäng on mõeldud 7–12-aastastele. Kuna ei koguta isikuandmeid ega looda kontosid, ei nõuta vanema nõusolekut; klassi loob ja koodi jagab tavaliselt täiskasvanu.

Viimati uuendatud: september 2026.
