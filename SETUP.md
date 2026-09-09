# Korrutaja – klassiversiooni käivitamine

Failid:

- `index.html` – kogu mäng (üks fail).
- `sw.js` – offline-tugi (service worker). Peab olema `index.html`-iga samas kaustas.
- `supabase.sql` – andmebaasi algskeem ja funktsioonid edetabeli jaoks.
- `supabase-migration-2…5.sql` – hilisemad DB-muudatused; jooksuta järjekorras pärast `supabase.sql`-i.
- `korrutaja.src.html` + `build.py` – lähtekood ja ehitusskript (`python3 build.py` teeb `index.html` ja `sw.js` uuesti; Supabase'i võtmed loeb `config.json`-ist). Vaja ainult siis, kui mängu muudetakse.

Ilma Supabase'ita töötab `index.html` ka: üks laps, edenemine telefonis, klassi liitumise nuppu ei näidata.

## 1. Supabase (andmebaas, tasuta) – u 5 min

1. supabase.com → New project. Region: **Frankfurt (eu-central-1)**. Andmebaasi parool pane kuhugi kirja, mängus seda vaja ei lähe.
2. Vasakul **SQL Editor** → New query → kleebi kogu `supabase.sql` sisu → **Run**. Peab lõppema "Success". Seejärel jooksuta samamoodi järjekorras `supabase-migration-2.sql`, `-3.sql`, `-4.sql` ja `-5.sql` (kool/tiim, päevalukk, rekord serverist, edetabeli skaleerimine).
3. **Project Settings → API Keys**: kopeeri **Project URL** (`https://xxxx.supabase.co`) ja **publishable** võti (`sb_publishable_...`).

Publishable-võti on mõeldud avalikuks – see on lehe koodis nähtav. Kaitse on andmebaasis: tabelitele otse ligi ei pääse, kõik käib funktsioonide kaudu, mis kontrollivad mängija salakoodi.

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

1. Ava aadress telefonis → **Liitu klassiga** → all **Loo uus** → vali **Kooliklass** (kooli nimi + klassiaste + täht, nt „Kesklinna Kool 3B“) või **Tiim** (vaba nimi, ei osale kooli- ega astmevõrdluses) → saad 6-märgilise koodi.
2. Kood + aadress klassile (õpetaja kaudu, klassi chat vms). Iga laps: ava aadress → Safari/Chrome "Jaga" → **Lisa avakuvale** → **Liitu klassiga** → kood + hüüdnimi. Kiirem on „Kutsu sõber klassi“ nupp edetabelis – see saadab lingi täidetud koodiga.
3. Mia liitub samamoodi sinu telefonist või enda omast.

Edetabelisse läheb ainult hüüdnimi ja võistlustulemused. Nime, e-posti ega parooli ei küsita – GDPR-i mõttes pole midagi hoida.

Teine klass loob lihtsalt oma koodi samal aadressil. **Kool**- ja **Eesti**-tabelid võrdlevad sama astme klasse võistluspunktidega ühe aktiivse võistleja kohta sel nädalal.

## Telefoni vahetus

Seaded → Klass → **taastekood** (8 märki). Uues telefonis: Liitu klassiga → "Mul on juba konto teises telefonis" → klassikood + hüüdnimi + taastekood. Edenemine tuleb serverist kaasa (server hoiab iga ringi järel koopiat).

## Teada tasub

- **Supabase'i tasuta projekt pausitakse, kui 7 päeva pole päringuid** (nt suvevaheaeg). Dashboardilt üks klõps "Restore" ja kõik on alles. Koolinädalatel seda ei juhtu.
- Tasuta piirid (500 MB, 50 000 kasutajat kuus) on mitme klassi jaoks lõputud.
- claude.ai artefakti-versioonis klassifunktsioone pole (seal on võrgupäringud blokeeritud) – see jääb isiklikuks harjutamiseks.
- Nädal algab esmaspäeval 00:00 Eesti aja järgi; "Nädal"-tabel nullib siis automaatselt.
