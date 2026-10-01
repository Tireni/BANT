# BANT Android Final Regression Checklist

Use this checklist before calling Android/web parity complete. Physical Android validation is required.

## Access and onboarding
- [ ] Fresh install boots without config/runtime errors.
- [ ] Google sign-in returns to Android.
- [ ] Existing session restores after restart.
- [ ] Profile onboarding saves display name, username and bio.
- [ ] Interests require at least three selections.
- [ ] Pending invite survives sign-in and onboarding.

## Home, rooms and creation
- [ ] Home public-room feed matches web-visible rooms.
- [ ] Live Now, Popular and New ordering is sensible.
- [ ] Rooms search, category filters and Live/Popular/New filters work.
- [ ] Create Room validates title, description, privacy and capacity.
- [ ] Capacity supports 5, 10, 15, 20, 30, 50, 75 and 100.
- [ ] Public and private rooms follow the same access rules as web.

## Room membership and voice
- [ ] Owner/speaker/listener roles render correctly.
- [ ] Android and web see joins/leaves without manual refresh.
- [ ] Android can hear web and web can hear Android.
- [ ] Speaker mute/unmute works.
- [ ] Listener cannot publish microphone audio.
- [ ] Owner-enforced mute cannot be bypassed by local unmute.
- [ ] Release restores local microphone control.
- [ ] Speaker/earpiece routing works.
- [ ] LiveKit reconnect state recovers after network interruption.
- [ ] Participant VOICE/TALKING/MUTED/OFFLINE states match actual media state.

## Chat and moderation
- [ ] Android-to-web chat appears in realtime.
- [ ] Web-to-Android chat appears in realtime.
- [ ] Duplicate chat messages do not appear.
- [ ] Owner can mute/release selected participants and all participants.
- [ ] Noise Control warns only and never force-mutes.
- [ ] End Room closes the room for all clients.

## Invitations
- [ ] Owner can generate a short invite link.
- [ ] Copy link works.
- [ ] Native Android share chooser opens.
- [ ] bant://invite/<token> opens the correct room.
- [ ] Logged-out invite returns to the same room after Google auth.
- [ ] Invite survives incomplete onboarding.
- [ ] Invalid, expired, revoked and ended-room invites fail safely.
- [ ] Private room cannot be entered with room ID alone.

## Social and safety
- [ ] Discover search works by display name and username.
- [ ] Send, accept, decline and cancel friend requests work cross-client.
- [ ] Friends tab shows accepted friends only.
- [ ] In-room social actions work.
- [ ] Block removes the user from normal social lists.
- [ ] Blocked tab allows unblock.
- [ ] User reports submit.
- [ ] Notifications load and mark read.

## Profile
- [ ] Display name, username and bio update.
- [ ] Invalid username is rejected.
- [ ] Avatar upload accepts JPEG/PNG/WebP up to 5 MB.
- [ ] Avatar persists after restart and appears on web.

## Release gate
- [ ] flutter analyze returns no issues.
- [ ] flutter test passes.
- [ ] Android/web critical flows above pass on physical devices.
- [ ] No background-audio claim is made until foreground Android/web voice is physically stable.
