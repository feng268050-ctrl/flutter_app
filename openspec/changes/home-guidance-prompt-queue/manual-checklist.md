## Manual checklist — home-guidance-prompt-queue

- [ ] Boot with startup self-check **on**: self-check dialog first; no guidance/warn over it
- [ ] After self-check: alarm can appear **before** cloud bind/register (disconnect Wi‑Fi or delay cloud)
- [ ] Late bind/register enqueue behind any open/queued warn; never two prompts at once
- [ ] Self-check **off** / already consumed: warn flush still works; Wi‑Fi tip when radio on + disconnected
- [ ] Confirm no private warn UI `Queue` remains; `dismiss(id)` closes pending/showing prompts
