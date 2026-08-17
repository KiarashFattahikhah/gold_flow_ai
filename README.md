# 📈 Gold Signal Dashboard — Mobile App

A Flutter mobile companion app for **[Gold-Trading-Platform-](https://github.com/KiarashFattahikhah/Gold-Trading-Platform-)**.

> **This repo *is* the mobile app for that platform.** The Streamlit repo above trains and runs the actual CNN‑GRU forecasting models and produces live BUY / SELL / DO NOTHING signals for gold (XAU/USD); this Flutter app is simply a phone-friendly window into that same signal log — pull-to-refresh signal cards, price charts, and full history, all backed by the exact same `live_signal_report_history.csv` the Streamlit dashboard writes.

---

## What it does

- **Live signal cards** for each configured forecast horizon (5‑minute and 15‑minute by default): current signal (BUY / SELL / DO NOTHING), predicted price range, current price, and a confidence meter.
- **Price chart** per horizon — actual price plotted as a continuous line, high/low forecast bands plotted alongside it (each row carries its own `predicted_close ± band half-width`), with the unrealized/near-future segment shown dashed. Toggle between 5m and 15m with two buttons instead of scrolling two stacked charts.
- **History screen** — full signal log, filterable by horizon, each entry graded against what actually happened (✅ correct / ⚠️ missed move / ⏳ pending / ❓ unverifiable), matching the grading logic in the Streamlit dashboard.
- **Auto-polling** — refreshes from the backend every 30 seconds while the app is open, plus manual pull-to-refresh.

---

## Architecture

```
┌─────────────────────────────┐
│  Gold-Trading-Platform-      │   trains models, runs live inference,
│  (Streamlit, separate repo)  │   writes live_signal_report_history.csv
└──────────────┬───────────────┘
               │ writes CSV
               ▼
┌─────────────────────────────┐
│  signal_server.py             │   tiny stdlib-only HTTP server,
│  (this repo, /server)         │   serves the CSV at /api/signals
└──────────────┬───────────────┘
               │ tunneled publicly (Tailscale Funnel / ngrok)
               ▼
┌─────────────────────────────┐
│  Flutter app (this repo)      │   polls the tunnel URL every 30s,
│  Home / Chart / History        │   parses CSV client-side, renders UI
└─────────────────────────────┘
```

The Flutter app never talks to the model or Streamlit dashboard directly — it only ever fetches the CSV snapshot over HTTP from `signal_server.py`. As long as that endpoint is reachable and serving fresh data, the app updates automatically; nothing else needs to know the app exists.

---

## Repo layout

```
lib/
├── main.dart
├── models/
│   ├── signal_row.dart        # one row of live_signal_report_history.csv
│   └── horizon_stats.dart     # per-horizon accuracy aggregation
├── services/
│   └── api_service.dart       # fetches + parses the CSV over HTTP
├── screens/
│   ├── home_screen.dart       # latest signal cards, polling loop
│   ├── chart_screen.dart      # 5m/15m price + forecast band chart
│   └── history_screen.dart    # full graded signal log
├── widgets/
│   └── signal_card.dart
├── theme/
│   └── app_theme.dart
└── utils/
    └── price_band.dart        # fixed prediction-interval half-widths per horizon

server/
└── signal_server.py           # stdlib-only HTTP server exposing the CSV
```

---

## Prerequisites

- Flutter SDK (stable channel)
- A running instance of **[Gold-Trading-Platform-](https://github.com/KiarashFattahikhah/Gold-Trading-Platform-)** actively writing `live_signal_report_history.csv`
- Python 3.8+ (for `signal_server.py` — standard library only, no installs needed)
- A way to expose `signal_server.py` publicly — [Tailscale Funnel](https://tailscale.com/kb/1223/funnel) (recommended: free, fixed hostname, no domain rotation) or [ngrok](https://ngrok.com) with a reserved domain

---

## Running the backend

1. **Point `CSV_PATH` in `signal_server.py`** at the exact file your model instance writes (see the platform repo's own README for where that ends up — typically inside a `run_*/horizon_*/` folder or wherever you've configured its autosave location).

   ```python
   CSV_PATH = r"path\to\live_signal_report_history.csv"
   ```

2. **Start the server:**

   ```bash
   python signal_server.py
   ```

   You should see `Serving: <path>` and `http://localhost:8000/api/signals` printed, with no traceback.

3. **Expose it publicly** (pick one):

   **Tailscale Funnel (recommended):**
   ```bash
   tailscale funnel 8000
   ```
   Prints a permanent `https://<your-device>.<your-tailnet>.ts.net` URL — this does not change between restarts.

   **ngrok (requires a reserved domain to stay stable):**
   ```bash
   ngrok http --url=<your-reserved-domain> 8000
   ```
   ⚠️ Running plain `ngrok http 8000` without `--url` issues a **new random subdomain every restart** on the free tier — the app will silently point at a dead tunnel until you update it.

4. **Sanity-check before touching the app:** open `<your-public-url>/api/signals` in a browser (ideally from a different network, e.g. phone on mobile data) and confirm you see raw CSV text, not an error page.

---

## Configuring the app

Set the backend URL in `lib/services/api_service.dart`:

```dart
static const String defaultBaseUrl = 'https://<your-public-url>/api/signals';
```

Or, without rebuilding, set it live from the app's **Settings** icon — it's persisted locally via `shared_preferences` and takes priority over the hardcoded default.

---

## Running the app

```bash
flutter pub get
flutter run
```

---

## ⚠️ Important caveats

- **This app has no forecasting logic of its own.** Every prediction, confidence score, and signal shown here is computed entirely by the model pipeline in [Gold-Trading-Platform-](https://github.com/KiarashFattahikhah/Gold-Trading-Platform-) — this repo only displays it.
- **The CSV must actually be growing.** The Streamlit dashboard's own auto-refresh (sidebar checkbox) is off by default and only continues looping while its browser tab stays open and connected — see that repo's README for details. If this app shows stale or flat-looking data, check that the upstream pipeline is actually still writing new rows, not just that the app can reach the server.
- **Public tunnel required.** Since the model typically runs on a personal machine, the app needs a stable public URL (Tailscale Funnel or a reserved ngrok domain) to reach it from a phone on a different network. A LAN‑only IP address only works if the phone and the machine running the model are on the same Wi‑Fi.
- **Short-horizon forecasts carry real uncertainty.** As stated in the platform repo: this is an informational tool, not financial advice.

---

## Credit

Forecasting models, feature engineering, and the Streamlit dashboard: **[Gold-Trading-Platform-](https://github.com/KiarashFattahikhah/Gold-Trading-Platform-)**. This repository is the mobile client for that project.

## video 



https://github.com/user-attachments/assets/df3189bd-ab20-4e79-b7c2-f2ce7f9f20e7

