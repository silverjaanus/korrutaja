# Korrutaja – klassiversiooni käivitamine

Failid:

- `index.html` – kogu mäng (üks fail).
- `sw.js` – offline-tugi (service worker). Peab olema `index.html`-iga samas kaustas.
- `supabase.sql` – andmebaasi skeem ja funktsioonid edetabeli jaoks.
- `korrutaja.src.html` + `build.py` – lähtekood ja ehitusskript (`python3 build.py` teeb `index.html` ja `sw.js` uuesti; Supabase'i võtmed loeb `config.json`-ist). Vaja ainult siis, kui mängu muudetakse.

Ilma Supabase'ita töötab `index.html` ka: üks laps, edenemine telefonis, klassi liitumise nuppu ei näidata.

## 1. Supabase (andmebaas, tasuta) – u 5 min

1. supabase.com → New project. Region: **Frankfurt (eu-central-1)**. Andmebaasi parool pane kuhugi kirja, mängus seda vaja ei lähe.
2. Vasakul **SQL Editor** → New query → kleebi kogu `supabase.sql` sisu → **Run**. Peab lõppema "Success".
3. **Project Settings → API**: kopeeri **Project URL** (`https://xxxx.supabase.co`) ja **anon public** võti (pikk `eyJ...` string).

Anon-võti on mõeldud avalikuks – see on lehe koodis nähtav. Kaitse on andmebaasis: tabelitele otse ligi ei pääse, kõik käib funktsioonide kaudu, mis kontrollivad mängija salakoodi.

## 2. Võti mängu

Pane URL ja publishable-võti faili `config.json` ja jooksuta `python3 build.py` – või ava `index.html` tekstiredaktoris, otsi rida `var SB={url:'',key:''};` ja täida käsitsi:

```
var SB={url:'https://xxxx.supabase.co',key:'sb_publishable_...'};
```

## 3. Veebi üles (Vercel Drop)

vercel.com/drop → lohista `korrutaja.zip` (või kaust, kus on `index.html` ja `sw.js`) → projekti nimi (nt `korrutaja`) → **Deploy**. Saad aadressi `korrutaja-xxxx.vercel.app`; Project Settings → Domains all saab lühema `korrutaja.vercel.app`, kui vaba.

Tee see samm **pärast** sammu 2 – iga Drop loob uue projekti uue aadressiga, olemasolevat projekti Drop ei uuenda. Hilisemad uuendused samale aadressile: `npx vercel --prod` samas kaustas (logib sisse brauseri kaudu, GitHubi pole vaja) või Netlify Drop, mis lubab sama saiti uuesti lohistades uuendada.

HTTPS on mõlemal – seda on vaja, et "Lisa avakuvale" ja offline-režiim töötaksid.

## 4. Klassi loomine ja jagamine

1. Ava aadress telefonis → **Liitu klassiga** → all **Loo uus klass** → nimi (nt `3B Kesklinna kool`) → saad 6-märgilise koodi.
2. Kood + aadress klassile (õpetaja kaudu, klassi chat vms). Iga laps: ava aadress → Safari/Chrome "Jaga" → **Lisa avakuvale** → **Liitu klassiga** → kood + hüüdnimi.
3. Mia liitub samamoodi sinu telefonist või enda omast.

Edetabelisse läheb ainult hüüdnimi ja vastuste arv. Nime, e-posti ega parooli ei küsita – GDPR-i mõttes pole midagi hoida.

Teine klass loob lihtsalt oma koodi samal aadressil. **Klassid**-tabel võrdleb klasse vastuste arvuga ühe aktiivse õpilase kohta sel nädalal.

## Telefoni vahetus

Seaded → Klass → **taastekood** (8 märki). Uues telefonis: Liitu klassiga → "Mul on juba konto teises telefonis" → klassikood + hüüdnimi + taastekood. Edenemine tuleb serverist kaasa (server hoiab iga ringi järel koopiat).

## Teada tasub

- **Supabase'i tasuta projekt pausitakse, kui 7 päeva pole päringuid** (nt suvevaheaeg). Dashboardilt üks klõps "Restore" ja kõik on alles. Koolinädalatel seda ei juhtu.
- Tasuta piirid (500 MB, 50 000 kasutajat kuus) on mitme klassi jaoks lõputud.
- claude.ai artefakti-versioonis klassifunktsioone pole (seal on võrgupäringud blokeeritud) – see jääb isiklikuks harjutamiseks.
- Nädal algab esmaspäeval 00:00 Eesti aja järgi; "Nädal"-tabel nullib siis automaatselt.
