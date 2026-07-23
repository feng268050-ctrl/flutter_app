## Why

Monitor -> Videos currently does not give a clear enough scrolling/loading experience for larger video lists. The pull/scroll hint text is too small to read comfortably, and the list needs explicit pagination feedback so operators know whether more videos are available or loading.

## What Changes

- Improve the readability of the dropdown/pull-scroll hint text used on Monitor -> Videos.
- Load the next page automatically when the user scrolls to the end of the list and more videos are available.
- Show a footer summary as `{n} of {total}` at the end of the list, where `n` is the number of loaded videos and `total` comes from the video list response.
- Replace the footer count with a loading state while a next page request is in progress.
- Prevent duplicate load-more requests while an existing page request is still pending.
- Update Monitor -> Videos table labels to use process/material terminology: `Process Type` and `Material Type`.
- Reduce the visual weight of row separators in the Monitor -> Videos list.
- Update the video details page copy and layout so process parameter labels use the new terminology, the section title remains fixed while details scroll, and the delete action uses Title Case.

## Capabilities

### New Capabilities

- `monitor-videos-list-pagination-ui`: UI behavior for Monitor -> Videos scrolling hints, infinite pagination, loading state, and loaded/total footer display.

### Modified Capabilities

- `device-ws-video-list-command`: Clarifies that Monitor -> Videos relies on the existing paginated `total` and `list` response contract for end-of-list loading and footer counts.

## Impact

- Affects Monitor -> Videos list UI, including its scroll component, pagination state, table labels, separators, and footer rendering.
- Affects process video details UI copy and the left-side process parameters layout.
- Uses the existing `command.video_list_request` / `command.video_list_response` pagination contract and `data.total`.
- No new backend API, database schema, or external dependency is expected.
