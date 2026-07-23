## 1. Locate Current Monitor Videos Flow

- [x] 1.1 Identify the Monitor -> Videos screen, adapter, layout resources, and video list request/response handling code.
- [x] 1.2 Confirm the current page size, page numbering, total parsing, refresh behavior, and end-of-list scroll callback path.
- [x] 1.3 Identify the dropdown, pull-scroll, or load-more hint view whose text appears too small.

## 2. Improve Scroll Hint Styling

- [x] 2.1 Increase the Monitor -> Videos scroll hint text size so it is not smaller than nearby video metadata labels.
- [x] 2.2 Prefer a Monitor -> Videos scoped style or layout override unless the existing shared component is intentionally used only by this page.
- [x] 2.3 Verify the updated hint remains visually aligned with existing colors, spacing, and HMI page styling.

## 3. Implement End-of-List Pagination

- [x] 3.1 Add or update list state for current page, page size, loaded count, latest total, initial loading, load-more loading, and has-more status.
- [x] 3.2 Reset pagination state on full refresh or query/filter changes, then replace the list with the first response page.
- [x] 3.3 Trigger a next-page request when the user reaches the list end and loaded count is less than latest total.
- [x] 3.4 Prevent duplicate next-page requests while a load-more request is already in flight.
- [x] 3.5 Append successful next-page rows to the current list and update total from the latest response.
- [x] 3.6 Clear load-more loading state on success, empty response, error, and cancellation paths.

## 4. Add Footer Count and Loading State

- [x] 4.1 Add a footer view or adapter footer for Monitor -> Videos list status.
- [x] 4.2 Show `{n} of {total}` when no next-page request is in flight.
- [x] 4.3 Show a loading message in the footer while fetching the next page.
- [x] 4.4 Stop showing load-more affordance and stop requesting pages after loaded count reaches total or a successful next page returns no rows.

## 5. Verification

- [x] 5.1 Verify the first page displays the correct footer count after initial load.
- [x] 5.2 Verify scrolling to the end loads additional data and appends rows without replacing existing rows.
- [x] 5.3 Verify repeated end-of-list scroll events do not produce duplicate requests while loading.
- [x] 5.4 Verify the footer switches from loading back to `{n} of {total}` after success or failure.
- [x] 5.5 Run the relevant Android build, lint, or focused tests available for the touched modules.

## 6. Copy and Layout Polish

- [x] 6.1 Rename Monitor -> Videos table headers to `Process Type` and `Material Type`.
- [x] 6.2 Reduce Monitor -> Videos row divider thickness so separators are visually lighter.
- [x] 6.3 Rename the process video details heading to `Process Parameters`.
- [x] 6.4 Rename the process video details process field to `Process Type` and material field to `Material Type`.
- [x] 6.5 Move the process video details heading outside the scrollable parameter rows so it remains fixed.
- [x] 6.6 Update the process video details delete action to Title Case `Delete`.
- [x] 6.7 Sync the updated UI to the target emulator with `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync`.
