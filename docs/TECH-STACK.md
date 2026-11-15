# Odyssey tech stack

Notes for the real app. This repo is the SwiftUI app. For now it keeps everything on the phone (a JSON file in the App Group shared with the widgets); Convex and Supermemory are the next pieces to plug in.

## How everything connects

```
Odyssey iOS App
SwiftUI, Camera, Location, Widgets, Globe
        |  talks both ways
Convex Backend
Profiles, Rewards, Adventures, Friends, Videos, Credits
        |
Supermemory
Personalization
```

## The pieces

| Piece | Role | Covers |
|---|---|---|
| Odyssey iOS App | The app people use, built in SwiftUI | Camera, Location, Widgets, Globe |
| Convex Backend | The backend the app talks to, in both directions | Profiles, Rewards, Adventures, Friends, Videos, Credits |
| Supermemory | Personalization | What Odyssey learns about each explorer |

## Decided against

Whop, which was listed as optional commerce, is not part of the stack.
