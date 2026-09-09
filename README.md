# Korrutaja

Korrutustabeli ja jagamise harjutamise mäng telefonile. Adaptiivne, ajastatud, klassi edetabeliga. Tasuta, ilma reklaami, kontode ja jälgimiseta.

**Mängi:** https://korrutaja.silverjaanus.com (või https://korrutaja.vercel.app)

*English summary at the bottom.*

## Mis see teeb

- Küsib korrutamist (`7 × 8`) ja jagamist (`56 : 7`) tabelites 1–10, vastus numbriklahvistikult.
- **Adaptiivne:** iga fakti kohta peetakse meeles täpsust ja kiirust. Raskemaid küsitakse sagedamini, vale või aeglane vastus tuleb 3–6 küsimuse pärast uuesti. Tabelid 1, 2, 5 ja 10 on eos harvemad, 6–9 sagedasemad (nii jaotuvad ka päris vead: [Caddingtoni kooli 60 000 vastuse analüüs](https://ibmathsresources.com/2013/06/01/which-times-tables-do-students-find-difficult-an-investigation/)).
- **Taimer** 4–10 s (vaikimisi 6) või rahulik režiim ilma taimerita. Aeg otsa = näidatakse õiget vastust, mitte punast risti.
- **Roheline** fakt: viimasest 10 vastusest ≥90% õiged ja mediaanaeg ≤3 s. Lävi ei sõltu seadetest.
- **Soojuskaart** 10×10: kus on nõrgad kohad. **Tabel**: kordamiseks.
- **Võistle:** 25 korrutamistehet × 6 s, tabelid 2–10 võrdselt, alati korrutamine (sinu seaded ei mõjuta), üks kord Eesti kalendripäevas – serveripoolne päevalukk (nagu Inglismaa riiklik Multiplication Tables Check).
- **Klass:** kood + hüüdnimi, ilma kontodeta. Edetabelid: nädala võistluspunktid (viie parima võistluspäeva summa, max 125), rohelised faktid, rekord (parim üksik võistlus), sama kooli klassid omavahel ja sama klassiaste üle Eesti (punkte aktiivse võistleja kohta).
- Töötab offline (PWA, „Lisa avakuvale“); edenemine on telefonis, klassiga liitunutel ka serveris varukoopiana.

## Miks nii

Meenutamine (retrieval practice) kinnistab paremini kui vaatamine või kooris kordamine ([Ophuis-Cox jt 2023](https://onlinelibrary.wiley.com/doi/10.1002/acp.4141)); lühikesed igapäevased sessioonid võidavad pikki harvu; vahetu tagasiside ja peatne uuesti küsimine on tugevaim mehhanism. Ajastatud testide ärevusrisk on maandatud sellega, et taimer on tempo, mitte hinne, ja on välja lülitatav. Edetabelitest on uuringutes positiivne mõju eeskätt absoluutsetel ja pingutust mõõtvatel tabelitel, mitte pingeridadel – sellepärast on „Nädal“ võistluspunktid (viie parima võistluspäeva summa, nädalavahetusel ei pea mängima) ja näidatakse esiseitset + enda rida.

## Failid

| Fail | Mis |
|---|---|
| `index.html` | Kogu mäng, üks fail. See on see, mis on üleval. |
| `sw.js` | Service worker (offline). |
| `korrutaja.src.html` | Lähtekood ilma `<html>/<head>` ümbriseta (sama sisu; sellest ehitatakse `index.html`). |
| `build.py` | Ehitab `index.html` + `sw.js` (ikoonid, manifest, Supabase'i võtmed `config.json`-ist). |
| `config.json` | Supabase'i URL ja avalik võti. |
| `.github/workflows/keepalive.yml` | Pingib andmebaasi kord päevas, et tasuta projekt vaheajal pausi ei läheks. |
| `supabase.sql` | Andmebaasi algskeem, RLS ja funktsioonid. |
| `supabase-migration-2…4.sql` | Hilisemad DB-muudatused järjekorras: kool/tiim ja astmevõrdlused (2), päevalukk ja viie parima päeva nädal (3), rekord serverist ja turvalisem koodigeneraator (4). |
| `SETUP.md` | Kuidas oma koopia üles panna (Supabase + Vercel). |
| `PRIVACY.md` | Mida hoitakse ja kus. |

## Turvamudel

Lehe koodis on Supabase'i **avalik** (publishable) võti – see on disainitud avalikuks. Tabelitele pole sellega ligipääsu (RLS sees, poliitikaid pole). Kogu liiklus käib SQL-funktsioonide kaudu (`create_group`, `join_class`, `restore_player`, `report_session`, `class_board`, `school_suggest`; vana `create_class` on tagasiühilduvuseks alles), mis kontrollivad mängija salakoodi ja piiravad väärtusi. Rekord ja päevalukk arvutatakse serveris, mitte kliendi numbrist. Server ei saa kunagi lapse nime, e-posti ega seadme andmeid.

## Oma versioon

Forgi, muuda `korrutaja.src.html`, jooksuta `python3 build.py`. Klassifunktsioonide jaoks tee oma Supabase'i projekt (`SETUP.md`). Litsents MIT – tee, mida tahad, viide on tore.

## English

Korrutaja (“Multiplier”) is an Estonian-language multiplication and division practice game for phones. Adaptive item selection (per-fact accuracy and response-time tracking, harder tables weighted up, missed items re-asked within 3–6 questions), per-question timer with a calm mode, mastery heatmap, a once-a-day server-enforced 25-question timed multiplication competition, and optional class leaderboards (weekly points from the five best competition days, mastery count, personal record, same-school and same-grade comparisons) via a 6-character class code and nickname – no accounts, no personal data, no ads or analytics. Single-file PWA on Vercel, Supabase (EU) for leaderboards, MIT licensed. The UI strings are in Estonian; the code is plain HTML/JS and easy to translate.

Made by [Silver Jaanus](https://silverjaanus.com) for his daughter.
