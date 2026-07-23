## Context

Monitor -> Videos displays process video rows from the existing paginated video list command. The device-side list contract already provides `data.list` and `data.total`, so this change should focus on client-side presentation and pagination state rather than introducing a new API.

The current page needs three user-facing improvements: the dropdown/pull-scroll hint text must be readable at HMI distance, scrolling to the end should fetch additional pages, and the list footer should communicate loaded count versus total count while also showing a loading state during page fetches.

## Goals / Non-Goals

**Goals:**

- Make Monitor -> Videos scroll hint text visually consistent with the rest of the page and large enough to read.
- Add end-of-list pagination that requests exactly one next page at a time.
- Maintain loaded item count, total count, current page, and loading state in the page controller or adapter state.
- Show `{n} of {total}` when not loading, and a loading message while more rows are being fetched.
- Stop requesting more pages once the loaded count reaches `total` or a returned page is empty.

**Non-Goals:**

- No change to video storage, upload status semantics, or WebSocket envelope names.
- No new backend endpoint or database schema change.
- No change to filtering, sorting, or upload progress dialog behavior beyond preserving list state after refresh/load-more operations.

## Decisions

- Reuse the existing `command.video_list_request` pagination contract. This keeps the UI aligned with existing device-side behavior and avoids introducing a second list source.

- Treat initial refresh and load-more as separate state transitions. Initial refresh can replace the list and reset page counters, while load-more appends the response list and increments the current page only after success.

- Gate load-more requests with an `isLoadingMore` flag and a `hasMore` check derived from `loadedCount < total`. This prevents duplicate page requests when scroll callbacks fire repeatedly near the bottom.

- Render the footer from state instead of hard-coding static text in item rows. A dedicated footer view or adapter footer keeps loading and count display independent from video rows.

- Increase the dropdown/pull-scroll hint text size locally for Monitor -> Videos unless the project already centralizes that component style. A local adjustment limits the blast radius; a shared style should only be changed if this page is the only consumer or all consumers require the same readability fix.

- Keep the video row adapter limited to video rows and render loaded/total status outside the adapter. This avoids RecyclerView item-position churn for a non-video footer while preserving stable row recycling during scroll.

- Keep the process details section title outside the scroll view. The title is a fixed section heading, while only process parameter rows should scroll; spacing should be controlled by the parent layout rather than title-specific bottom margins inside the scroll content.

- Standardize user-visible terminology in this flow around `Process Type`, `Material Type`, and `Process Parameters`. The details page delete action should use Title Case (`Delete`) to match other action labels.

## Risks / Trade-offs

- Repeated end-of-scroll callbacks could issue duplicate requests -> guard with a single in-flight load-more flag and ignore callbacks while loading.

- Stale totals after filters, refresh, or deletion could produce incorrect footer counts -> reset pagination state on every full refresh and update `total` from the newest successful list response.

- Empty or failed next-page responses could leave the footer stuck in loading -> always clear loading state on success, error, and cancellation paths; mark `hasMore` false for empty successful pages.

- Text-size changes in a shared scroll component could affect other pages -> prefer a Monitor -> Videos scoped style unless a shared style change is intentionally desired during implementation.

- Moving details headings outside scroll content can affect row background striping -> keep row striping scoped to the parameter row container rather than relying on the heading being a skipped child.
