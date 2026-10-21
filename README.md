# Pharmaify

Two apps in one: a pharmacy counter and the customer who orders from it.

- **Customer side** — browse local pharmacies and their stock, send a refill request with a photo of the script, watch it move Submitted → Received → Filling → Ready, get a notification when it's ready, set dose reminders.
- **Pharmacy side** — live queue of incoming requests, one-tap status advance, inventory with low-stock flags, store profile.

Both sides share one SwiftData store, so on a single phone an order placed as a customer shows up on the pharmacy queue immediately.

iOS 26, SwiftUI + SwiftData, XcodeGen (`project.yml` is the source of truth). Builds in CI only; the `adhoc` job publishes an install page at https://assiamahs.github.io/pharmaify/install.html.
