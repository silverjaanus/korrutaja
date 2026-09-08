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
- **Kontroll:** 25 küsimust × 6 s, tabelid 2–10 võrdselt (nagu Inglismaa riiklik Multiplication Tables Check).
- **Klass:** kood + hüüdnimi, ilma kontodeta. Edetabelid: nädala õiged vastused (pingutus), rohelised faktid, parim Kontroll, klassid omavahel (õigeid vastuseid aktiivse õpilase kohta).
- Töötab offline (PWA, „Lisa avakuvale“); edenemine on telefonis, klassiga liitunutel ka serveris varukoopiana.

## Miks nii

Meenutamine (retrieval practice) kinnistab paremini kui vaatamine või kooris kordamine ([Ophuis-Cox jt 2023](https://onlinelibrary.wiley.com/doi/10.1002/acp.4141)); lühikesed igapäevased sessioonid võidavad pikki harvu; vahetu tagasiside ja peatne uuesti küsimine on tugevaim mehhanism. Ajastatud testide ärevusrisk on maandatud sellega, et taimer on tempo, mitte hinne, ja on välja lülitatav. Edetabelitest on uuringutes positiivne mõju eeskätt absoluutsetel ja pingutust mõõtvatel tabelitel, mitte pingeridadel – sellepärast on „Nädal“ õigete vastuste arv ja näidatakse esiseitset + enda rida.

## Failid

| Fail | Mis |
|---|---|
| `index.html` | Kogu mäng, üks fail. See on see, mis on üleval. |
| `sw.js` | Service worker (offline). |
| `korrutaja.src.html` | Lähtekood ilma `<html>/<head>` ümbriseta (sama sisu; sellest ehitatakse `index.html`). |
| `build.py` | Ehitab `index.html` + `sw.js` (ikoonid, manifest, Supabase'i võtmed `config.json`-ist). |
| `config.json` | Supabase'i URL ja avalik võti. |
| `.github/workflows/keepalive.yml` | Pingib andmebaasi kord päevas, et tasuta projekt vaheajal pausi ei läheks. |
| `supabase.sql` | Andmebaasi skeem, RLS ja funktsioonid. |
| `SETUP.md` | Kuidas oma koopia üles panna (Supabase + Vercel). |
| `PRIVACY.md` | Mida hoitakse ja kus. |

## Turvamudel

Lehe koodis on Supabase'i **avalik** (publishable) võti – see on disainitud avalikuks. Tabelitele pole sellega ligipääsu (RLS sees, poliitikaid pole). Kogu liiklus käib viie SQL-funktsiooni kaudu (`create_class`, `join_class`, `restore_player`, `report_session`, `class_board`), mis kontrollivad mängija salakoodi ja piiravad väärtusi. Server ei saa kunagi lapse nime, e-posti ega seadme andmeid.

## Oma versioon

Forgi, muuda `korrutaja.src.html`, jooksuta `python3 build.py`. Klassifunktsioonide jaoks tee oma Supabase'i projekt (`SETUP.md`). Litsents MIT – tee, mida tahad, viide on tore.

## English

Korrutaja (“Multiplier”) is an Estonian-language multiplication and division practice game for phones. Adaptive item selection (per-fact accuracy and response-time tracking, harder tables weighted up, missed items re-asked within 3–6 questions), per-question timer with a calm mode, mastery heatmap, a 25-question timed check, and optional class leaderboards via a 6-character class code and nickname – no accounts, no personal data, no ads or analytics. Single-file PWA on Vercel, Supabase (EU) for leaderboards, MIT licensed. The UI strings are in Estonian; the code is plain HTML/JS and easy to translate.

Made by [Silver Jaanus](https://silverjaanus.com) for his daughter.
