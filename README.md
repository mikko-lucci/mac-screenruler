# ScreenRuler for macOS

Näytön viivain, joka toimii kuten Windowsin PowerToys Screen Ruler. Sovellus elää valikkorivillä.

## Kääntäminen

```bash
./build.sh           # → build/ScreenRuler.app
./build.sh install   # kopioi /Applications-kansioon ja käynnistää
```

Vaatii macOS 14:n tai uudemman sekä Xcoden / Swift 5.9:n tai uudemman.

## Käyttö

| Toiminto | Näppäin |
|---|---|
| Käynnistä / sulje viivain | ⌘⇧M |
| Sulje | Esc |
| Rajat (vedä suorakulmio) | 1 |
| Välit (vaaka + pysty, reunantunnistus) | 2 |
| Vaakasuora väli | 3 |
| Pystysuora väli | 4 |
| Kopioi mitta | klikkaus / ⌘C |
| Säilytä mitta näytöllä | ⇧ + klikkaus (tai ⇧ + vedon päättäminen) |
| Tyhjennä säilytetyt mitat | oikea klikkaus / ⌫ |
| Siirrä osoitinta 1 px (⇧ = 10 px) | nuolinäppäimet |

Asetuksista (valikkorivin ikoni → Asetukset…) voi valita yksikön (px, pt, in, cm, mm), reunantunnistuksen
toleranssin, värikanavittaisen tunnistuksen, jatkuvan näytönkaappauksen, viivan värin ja käynnistyksen kirjautuessa.

## Näytön tallennuslupa

Reunantunnistus lukee näytön pikseleitä, joten sovellus tarvitsee luvan kohdasta
*Järjestelmäasetukset → Tietosuoja ja suojaus → Näytön ja äänen tallennus*.
macOS sitoo luvan sovelluksen allekirjoitukseen. Ad hoc -allekirjoitus muuttuu jokaisessa käännöksessä,
jolloin lupaa kysytään uudelleen. Luo siksi kerran paikallinen allekirjoitusvarmenne:

```bash
./Scripts/create-signing-cert.sh
```

`build.sh` käyttää sitä automaattisesti. Toisen identiteetin voi antaa näin: `SIGN_ID="Apple Development: …" ./build.sh`.
