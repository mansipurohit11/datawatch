# 🔍 DataWatch

### Because your pipeline said ✅ and lied to your face.

---

## What is this?

You know that feeling when your data pipeline runs perfectly, shows a happy green checkmark, and then an analyst pings you at 9 AM saying "hey why does our revenue dashboard say we made €400 this quarter?"

Yeah. That.

Turns out the payments API quietly changed its date format at 3 AM, your pipeline had no idea, ingested garbage data without blinking, and now the entire BI team thinks the company is bankrupt. Cool. Everything is fine.

**DataWatch** is a self-monitoring data pipeline that catches this stuff *before* the Slack messages start. It ingests from multiple sources, runs automated quality checks after every load, and when something breaks — instead of logging a cryptic `check_values_between FAILED` that nobody understands — it calls an LLM, gets a plain-English diagnosis of what probably went wrong, and sends it straight to Slack.

Real output, real example:

> *"The `orders.unit_price` column has 847 values above €5,000, which is 100x the typical range. This started at 3:47 AM, coinciding with a deployment in the upstream payments service. Likely cause: prices are now being sent in cents instead of euros. Suggested fix: divide values by 100 for records after this timestamp."*

That's the message your on-call engineer gets. Instead of "something broke, good luck."

---

## How it works

Three layers. Each one built on top of the last.

**Layer 1 — The actual pipeline**

Airflow pulls data from three sources: a live weather API, a PostgreSQL transactional database full of fake orders, and a CSV product catalog that vendors "drop" every morning. Everything lands in S3 (MinIO locally), gets cleaned, and loads into the warehouse. Standard stuff. This is the part every data engineer knows how to do.

**Layer 2 — Automated quality checks**

After every load, a suite of checks runs automatically. Row counts within expected ranges? No surprise nulls in critical columns? Prices actually look like prices and not like someone multiplied them by 100? These checks run every single time without anyone having to remember to do it. Results get stored in a metadata database so you have history.

**Layer 3 — The AI part (the fun part)**

When a check fails, the context — what broke, sample data, historical baselines, when it started — goes to GPT-4o-mini. It comes back with a diagnosis written like a senior engineer who looked at the data, not a stack trace written by a machine. That diagnosis goes to Slack automatically. You wake up, you already know what happened, you already know the fix.

---

## The stack

| Thing | What it does |
|-------|-------------|
| Apache Airflow | Orchestrates everything. The conductor. |
| PostgreSQL (x4) | Source DB, warehouse, Airflow internals, metadata store |
| MinIO | Local S3. Object storage for raw + processed data |
| Python | All pipeline code |
| OpenAI GPT-4o-mini | The AI diagnosis layer |
| Slack Webhooks | Where the alerts actually go |
| Streamlit | Dashboard showing pipeline health over time |
| Docker Compose | One command to start everything |

Yes, four separate PostgreSQL instances. No, that's not overkill. In real companies these are completely separate systems owned by completely separate teams. Might as well build the right habits now.

---

## Getting started

### What you need

- Docker + Docker Compose v2
- An OpenAI API key (optional — the pipeline works without it, you just get less interesting failure messages)
- A Slack webhook URL (optional — alerts go to logs instead)
- A free OpenWeatherMap API key (optional — synthetic data fills in if you skip this)

### One command

```bash
git clone https://github.com/mansipurohit11/datawatch.git
cd datawatch
cp .env.example .env
# fill in your keys in .env
./scripts/quickstart.sh
```

That starts everything. Databases, MinIO, Airflow, Streamlit. The whole thing.

Then open Airflow at `http://localhost:8080` (admin / admin), trigger the `datawatch_pipeline` DAG, and watch three sub-pipelines run in parallel.

### Actually testing the fun part

The pipeline by itself just moves clean data around. Boring, but important. To see the AI diagnosis layer kick in:

```bash
python scripts/inject_anomalies.py --anomaly price_in_cents
```

This simulates the currency unit change scenario — suddenly prices are 100x too high. Trigger the DAG again. Watch the quality checks catch it, watch the AI explain exactly what happened, watch the Slack message appear.

Available anomalies to inject:

```bash
--anomaly price_in_cents   # EUR → cents, 100x price spike
--anomaly volume_drop      # deletes 90% of today's orders (upstream outage sim)
--anomaly null_ids         # blanks out customer IDs (broken ETL sim)
--anomaly duplicates       # double-loads 50 orders (rerun bug sim)
--anomaly all              # chaos mode. all of the above.
```

---

## Project structure

```
datawatch/
├── dags/
│   └── datawatch_pipeline.py    # The main DAG. All three layers live here.
├── src/
│   ├── config.py                # All settings in one place
│   ├── storage.py               # S3/MinIO read/write
│   ├── metadata_store.py        # Logs everything to the metadata DB
│   ├── extractors/
│   │   ├── weather_extractor.py # Pulls from OpenWeatherMap API
│   │   ├── orders_extractor.py  # Reads from source PostgreSQL
│   │   └── file_extractor.py    # Reads vendor CSV drops
│   ├── transformers/
│   │   └── transform.py         # Cleans and standardises everything
│   ├── loaders/
│   │   └── loader.py            # Upserts into the warehouse
│   ├── quality/
│   │   └── checks.py            # All the quality checks
│   ├── ai/
│   │   └── diagnoser.py         # The GPT-4o-mini integration
│   └── notifications/
│       └── slack_notifier.py    # Formats and sends Slack alerts
├── streamlit_app/
│   └── app.py                   # Pipeline health dashboard
├── docker/
│   ├── warehouse_init.sql
│   ├── source_init.sql          # Seeds 1,500 fake orders on first boot
│   └── metadata_init.sql
├── scripts/
│   ├── quickstart.sh            # Start everything
│   └── inject_anomalies.py     # Break things on purpose
└── docker-compose.yml           # The whole infrastructure
```

---

## What the dashboard looks like

Open `http://localhost:8501` after running the pipeline a few times. You get:

- Pipeline health per run — rows loaded, checks passed, checks failed
- Quality pass rate over time, per pipeline, as a trend line
- Every AI diagnosis, expandable, with the suggested fix
- The raw list of failed checks with sample data that triggered them

It's not pretty in a "we hired a designer" way. It's pretty in a "you can actually understand what's going on in your data infrastructure" way. Different kind of pretty.

---

## Why this project exists

Data engineering interviews in Germany — especially at companies like Zalando, N26, Delivery Hero — don't just want to know if you can move data from A to B. They want to know if you understand that the data has to be *trustworthy* when it arrives.

This project shows both things: solid pipeline fundamentals (Airflow, S3, PostgreSQL, incremental loads, upserts, idempotency) *and* the applied AI layer that turns cryptic failures into actionable diagnoses. That combination is genuinely what's being hired for right now.

Also honestly it's a problem that's annoyed me since I first read about how much time data teams spend on "why does this number look weird" instead of actual analysis. So here's an attempt at fixing it.

---

## What's coming

- [ ] dbt models for the warehouse layer
- [ ] Kafka as a fourth data source (event stream ingestion)
- [ ] Statistical anomaly detection using z-scores instead of just fixed thresholds
- [ ] Great Expectations integration replacing the custom check engine
- [ ] CI/CD with GitHub Actions

---

## Want to run into issues?

You will. Here are the ones that will happen:

**Airflow won't start** — give it 60 seconds. It's doing a lot on first boot. If it still won't start, run `docker compose logs airflow-webserver` and read the error.

**MinIO bucket doesn't exist** — open `http://localhost:9001`, log in with `minioadmin / minioadmin`, create a bucket called `datawatch-lake` manually. The automation sometimes loses the race condition.

**AI diagnosis says "fallback"** — your `OPENAI_API_KEY` in `.env` is missing or wrong. The pipeline still works, the messages are just less interesting.

**Port already in use** — something on your machine is using 8080 or 5432. Change the left-hand port number in `docker-compose.yml` (the one before the colon).

---

## License

MIT. Use it, fork it, put it in your portfolio, bring it to an interview. Just don't claim you invented the idea of making data pipelines self-aware. That one belongs to every data engineer who ever got an angry Slack message about a dashboard.

---

*Built with ☕ and a deep personal grudge against silent data failures by [Mansi](https://github.com/mansipurohit11)*
